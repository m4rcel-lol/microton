# frozen_string_literal: true

class Trends::Statuses < Trends::Base
  PREFIX = 'trending_statuses'

  BATCH_SIZE = 100
  CACHE_LIMIT = 500
  CACHE_TTL = 15.minutes

  self.default_options = {
    threshold: 5,
    review_threshold: 3,
    score_halflife: 6.hours.freeze,
    decay_threshold: 0.3,
  }

  class Query < Trends::Query
    def initialize(prefix, klass, trends)
      super(prefix, klass)
      @trends = trends
    end

    def to_arel
      scope = if @allowed
                ordered_allowed_statuses
              else
                statuses_by_trend_score
              end

      scope = scope.not_excluded_by_account(@account).not_domain_blocked_by_account(@account).not_followed_by_account(@account) if @account.present?
      scope = scope.offset(@offset) if @offset.present?
      scope = scope.limit(@limit) if @limit.present?
      scope
    end

    private

    def ordered_allowed_statuses
      ids = @trends.cached_allowed_status_ids(preferred_languages)
      return Status.none if ids.empty?

      Status
        .where(id: ids)
        .reorder(Arel.sql("array_position(ARRAY[#{ids.join(',')}]::bigint[], statuses.id)"))
    end

    def statuses_by_trend_score
      scope = Status.joins(:trend).reorder(score: :desc)
      scope = scope.reorder(language_order_clause, score: :desc) if preferred_languages.present?
      scope
    end

    def trend_class
      StatusTrend
    end
  end

  def register(status, at_time = Time.now.utc)
    add(status.proper, status.account_id, at_time) if eligible?(status.proper, at_time)
  end

  def add(status, _account_id, at_time = Time.now.utc)
    record_used_id(status.id, at_time)
  end

  def query
    Query.new(key_prefix, klass, self)
  end

  def refresh(at_time = Time.now.utc)
    # First, recalculate scores for statuses that were trending previously. We split the queries
    # to avoid having to load all of the IDs into Ruby just to send them back into Postgres
    Status.where(id: StatusTrend.select(:status_id)).includes(:status_stat, :account).reorder(nil).find_in_batches(batch_size: BATCH_SIZE) do |statuses|
      calculate_scores(statuses, at_time)
    end

    # Then, calculate scores for statuses that were used today. There are potentially some
    # duplicate items here that we might process one more time, but that should be fine
    Status.where(id: recently_used_ids(at_time)).includes(:status_stat, :account).reorder(nil).find_in_batches(batch_size: BATCH_SIZE) do |statuses|
      calculate_scores(statuses, at_time)
    end

    # Now that all trends have up-to-date scores, and all the ones below the threshold have
    # been removed, we can recalculate their positions
    StatusTrend.recalculate_ordered_rank
    refresh_cached_allowed_status_ids
  end

  def cached_allowed_status_ids(preferred_languages = nil)
    cached = redis.get(allowed_status_ids_cache_key(preferred_languages))
    return decode_cached_ids(cached) if cached.present?

    refresh_cached_allowed_status_ids(preferred_languages)
  end

  def request_review
    StatusTrend.locales.flat_map do |language|
      score_at_threshold = StatusTrend.where(language: language, allowed: true).by_rank.ranked_below(options[:review_threshold]).first&.score || 0
      status_trends      = StatusTrend.where(language: language, allowed: false).joins(:status).includes(status: :account)

      status_trends.filter_map do |trend|
        status = trend.status

        if trend.score > score_at_threshold && !status.trendable? && status.requires_review_notification?
          status.account.touch(:requested_review_at)
          status
        end
      end
    end
  end

  protected

  def key_prefix
    PREFIX
  end

  def klass
    Status
  end

  private

  def eligible?(status, at_time = Time.now.utc)
    status.created_at.past? &&
      status.created_at >= at_time - 24.hours &&
      opted_into_trends?(status) &&
      !sensitive_content?(status) &&
      !status.reply? &&
      valid_locale?(status.language) &&
      (status.quote.nil? || trendable_quote?(status.quote))
  end

  def opted_into_trends?(status)
    status.public_visibility? &&
      status.account.discoverable? &&
      !status.account.silenced?
  end

  def sensitive_content?(status)
    status.account.sensitized? || status.spoiler_text.present? || status.sensitive?
  end

  def trendable_quote?(quote)
    quote.acceptable? &&
      quote.quoted_status.present? &&
      opted_into_trends?(quote.quoted_status) &&
      !sensitive_content?(quote.quoted_status)
  end

  def calculate_scores(statuses, at_time)
    items = statuses.map do |status|
      observed = (status.reblogs_count + status.replies_count + status.favourites_count).to_f

      score = observed < options[:threshold] ? 0 : observed

      decaying_score = if score.zero? || !eligible?(status, at_time)
                         0
                       else
                         score * (0.5**((at_time.to_f - status.created_at.to_f) / options[:score_halflife].to_f))
                       end

      [decaying_score, status]
    end

    to_insert = items.filter { |(score, _)| score >= options[:decay_threshold] }
    to_delete = items.filter { |(score, _)| score < options[:decay_threshold] }

    StatusTrend.upsert_all(to_insert.map { |(score, status)| { status_id: status.id, account_id: status.account_id, score: score, language: status.language, allowed: status.trendable? || false } }, unique_by: :status_id) if to_insert.any?
    StatusTrend.where(status_id: to_delete.map { |(_, status)| status.id }).delete_all if to_delete.any?
  end

  def refresh_cached_allowed_status_ids(preferred_languages = nil)
    ids = uncached_allowed_status_ids(preferred_languages)

    redis.set(allowed_status_ids_cache_key(preferred_languages), ids.join(','), ex: CACHE_TTL.to_i)
    ids
  end

  def uncached_allowed_status_ids(preferred_languages)
    scope = Status.joins(:trend).merge(StatusTrend.allowed).reorder(score: :desc)
    scope = scope.reorder(language_order_clause(preferred_languages), score: :desc) if preferred_languages.present?

    scope.limit(CACHE_LIMIT).pluck(:id)
  end

  def allowed_status_ids_cache_key(preferred_languages)
    locale_key = Array(preferred_languages).compact_blank.join(',')
    locale_key = 'all' if locale_key.blank?

    "#{PREFIX}:allowed_ids:v1:#{Digest::SHA256.hexdigest(locale_key)}"
  end

  def decode_cached_ids(value)
    value.split(',').filter_map { |id| id.presence&.to_i }
  end

  def language_order_clause(preferred_languages)
    Arel::Nodes::Case
      .new
      .when(StatusTrend.arel_table[:language].in(Array(preferred_languages)))
      .then(1)
      .else(0)
      .desc
  end
end
