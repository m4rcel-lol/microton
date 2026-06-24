# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountSuggestions::FollowedTagsSource do
  describe '#get' do
    subject { described_class.new }

    let(:account) { Fabricate(:account) }
    let(:followed_tag) { Fabricate(:tag, name: 'followed') }
    let(:other_tag) { Fabricate(:tag, name: 'other') }

    before do
      Fabricate(:tag_follow, account: account, tag: followed_tag)
    end

    it 'returns accounts active in followed hashtags ordered by recent public activity' do
      less_active = Fabricate(:account, discoverable: true)
      more_active = Fabricate(:account, discoverable: true)

      Fabricate(:status, account: less_active, tags: [followed_tag], visibility: :public, created_at: 1.day.ago)
      Fabricate.times(2, :status, account: more_active, tags: [followed_tag], visibility: :public, created_at: 1.day.ago)

      expect(subject.get(account)).to start_with(
        [more_active.id, :followed_tags],
        [less_active.id, :followed_tags]
      )
    end

    it 'does not return ineligible accounts' do
      followed = Fabricate(:account, discoverable: true)
      private_poster = Fabricate(:account, discoverable: true)
      stale_poster = Fabricate(:account, discoverable: true)
      other_tag_poster = Fabricate(:account, discoverable: true)
      undiscoverable = Fabricate(:account, discoverable: false)
      eligible = Fabricate(:account, discoverable: true)

      account.follow!(followed)

      Fabricate(:status, account: followed, tags: [followed_tag], visibility: :public, created_at: 1.day.ago)
      Fabricate(:status, account: private_poster, tags: [followed_tag], visibility: :private, created_at: 1.day.ago)
      Fabricate(:status, account: stale_poster, tags: [followed_tag], visibility: :public, created_at: 15.days.ago)
      Fabricate(:status, account: other_tag_poster, tags: [other_tag], visibility: :public, created_at: 1.day.ago)
      Fabricate(:status, account: undiscoverable, tags: [followed_tag], visibility: :public, created_at: 1.day.ago)
      Fabricate(:status, account: eligible, tags: [followed_tag], visibility: :public, created_at: 1.day.ago)

      results = subject.get(account)

      expect(results)
        .to include([eligible.id, :followed_tags])
        .and not_include([followed.id, :followed_tags])
        .and not_include([private_poster.id, :followed_tags])
        .and not_include([stale_poster.id, :followed_tags])
        .and not_include([other_tag_poster.id, :followed_tags])
        .and not_include([undiscoverable.id, :followed_tags])
    end

    it 'returns no suggestions when the account follows no hashtags' do
      TagFollow.where(account: account).delete_all

      expect(subject.get(account)).to be_empty
    end
  end
end
