import classNames from 'classnames';

import logo from '@/images/logo.svg';
import { title as siteTitle } from 'mastodon/initial_state';

const productName = 'Microton';
const logoTitle = siteTitle ?? productName;

export const WordmarkLogo: React.FC = () => (
  <svg viewBox='0 0 261 66' className='logo logo--wordmark' role='img'>
    <title>{productName}</title>
    <text
      x='0'
      y='50'
      fill='currentColor'
      fontFamily='Inter, system-ui, sans-serif'
      fontSize='50'
      fontWeight='700'
    >
      {productName}
    </text>
  </svg>
);

export const IconLogo: React.FC<{ className?: string }> = ({ className }) => (
  <svg
    viewBox='0 0 79 79'
    className={classNames('logo logo--icon', className)}
    role='img'
  >
    <title>{logoTitle}</title>
    <use xlinkHref='#logo-symbol-icon' />
  </svg>
);

export const SymbolLogo: React.FC = () => (
  <img src={logo} alt={logoTitle} className='logo logo--icon' />
);
