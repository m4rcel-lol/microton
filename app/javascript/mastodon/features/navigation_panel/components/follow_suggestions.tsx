import { useEffect, useState } from 'react';

import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { fetchRelationships } from 'mastodon/actions/accounts';
import { importFetchedAccounts } from 'mastodon/actions/importer';
import { apiGetSuggestions } from 'mastodon/api/suggestions';
import { Account } from 'mastodon/components/account';
import { useAppDispatch } from 'mastodon/store';

const SUGGESTIONS_LIMIT = 5;

export const FollowSuggestions: React.FC = () => {
  const dispatch = useAppDispatch();
  const [accountIds, setAccountIds] = useState<string[]>([]);

  useEffect(() => {
    let active = true;

    void apiGetSuggestions(SUGGESTIONS_LIMIT)
      .then((suggestions) => {
        if (!active) {
          return;
        }

        const accounts = suggestions.map(({ account }) => account);
        const ids = accounts.map(({ id }) => id);

        dispatch(importFetchedAccounts(accounts));
        dispatch(fetchRelationships(ids));
        setAccountIds(ids);
      })
      .catch(() => {
        if (active) {
          setAccountIds([]);
        }
      });

    return () => {
      active = false;
    };
  }, [dispatch]);

  if (accountIds.length === 0) {
    return null;
  }

  return (
    <aside className='navigation-panel__portal'>
      <div className='getting-started__trends'>
        <h2 className='getting-started__trends-heading'>
          <Link to='/suggestions'>
            <FormattedMessage
              id='follow_suggestions.who_to_follow'
              defaultMessage='Who to follow'
            />
          </Link>
        </h2>

        {accountIds.map((accountId) => (
          <Account
            key={accountId}
            id={accountId}
            size={36}
            withBorder={false}
            withMenu={false}
          />
        ))}

        <Link to='/suggestions' className='link-button'>
          <FormattedMessage
            id='follow_suggestions.view_all'
            defaultMessage='View all'
          />
        </Link>
      </div>
    </aside>
  );
};
