# frozen_string_literal: true

class AccountSuggestions::FollowedTagsSource < AccountSuggestions::Source
  RECENT_ACTIVITY_WINDOW = 14.days

  def get(account, limit: DEFAULT_LIMIT)
    return [] unless TagFollow.where(account_id: account.id).exists?

    source_scope(account)
      .limit(limit)
      .pluck('accounts.id')
      .zip([key].cycle)
  end

  def source_scope(account)
    base_account_scope(account)
      .joins(:statuses)
      .joins('INNER JOIN statuses_tags ON statuses_tags.status_id = statuses.id')
      .left_joins(:account_stat)
      .where(statuses_tags: { tag_id: TagFollow.where(account_id: account.id).select(:tag_id) })
      .where(statuses: { deleted_at: nil, reblog_of_id: nil, visibility: Status.visibilities[:public] })
      .where('statuses.created_at >= ?', RECENT_ACTIVITY_WINDOW.ago)
      .group('accounts.id', 'account_stats.followers_count')
      .order(
        Arel.sql('COUNT(DISTINCT statuses.id) DESC'),
        Arel.sql('COALESCE(account_stats.followers_count, 0) DESC'),
        Account.arel_table[:id].desc
      )
  end

  private

  def key
    :followed_tags
  end
end
