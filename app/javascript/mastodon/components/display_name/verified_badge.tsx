import type { FC } from 'react';

import { defineMessage, useIntl } from 'react-intl';

import IconVerified from '@/images/icons/icon_verified.svg?react';

import { Icon } from '../icon';

const verifiedBadgeMessage = defineMessage({
  id: 'account.verified_badge',
  defaultMessage: 'Verified',
});

export const DisplayNameVerifiedBadge: FC = () => {
  const intl = useIntl();
  const label = intl.formatMessage(verifiedBadgeMessage);

  return (
    <span className='display-name__verified-badge' title={label}>
      <Icon
        id='verified'
        icon={IconVerified}
        noFill
        aria-label={label}
      />
    </span>
  );
};
