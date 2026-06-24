# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::SuggestionSerializer do
  let(:serialization) { serialized_record_json(record, described_class, options: { scope: current_user, scope_name: :current_user }) }
  let(:current_user) { Fabricate(:user) }
  let(:record) do
    AccountSuggestions::Suggestion.new(
      account: account,
      sources: ['SuggestionSource']
    )
  end
  let(:account) { Fabricate(:account) }

  describe 'account' do
    it 'returns the associated account' do
      expect(serialization['account']['id']).to eq(account.id.to_s)
    end
  end

  context 'with a followed tags source' do
    let(:record) do
      AccountSuggestions::Suggestion.new(
        account: account,
        sources: [:followed_tags]
      )
    end

    it 'maps to the legacy personalized source' do
      expect(serialization['source']).to eq('past_interactions')
    end
  end
end
