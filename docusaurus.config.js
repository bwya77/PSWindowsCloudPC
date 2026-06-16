// @ts-check

const lightCodeTheme = require('prism-react-renderer').themes.github;
const darkCodeTheme = require('prism-react-renderer').themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'WindowsCloudPC',
  tagline: 'PowerShell automation and documentation for Windows 365 Cloud PCs',
  favicon: 'img/logo.svg',

  url: 'https://bwya77.github.io',
  baseUrl: '/PSWindowsCloudPC/',
  organizationName: 'bwya77',
  projectName: 'PSWindowsCloudPC',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: 'docs',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/bwya77/PSWindowsCloudPC/tree/main/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo.svg',
      navbar: {
        title: 'WindowsCloudPC',
        logo: {
          alt: 'WindowsCloudPC logo',
          src: 'img/logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Docs',
          },
          { to: '/docs/commands/', label: 'Commands', position: 'left' },
          { to: '/docs/examples', label: 'Examples', position: 'left' },
          {
            href: 'https://www.powershellgallery.com/packages/WindowsCloudPC',
            label: 'PowerShell Gallery',
            position: 'right',
          },
          {
            href: 'https://github.com/bwya77/PSWindowsCloudPC',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              { label: 'Getting started', to: '/docs/getting-started' },
              { label: 'Command reference', to: '/docs/commands/' },
              { label: 'Examples', to: '/docs/examples' },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/bwya77/PSWindowsCloudPC',
              },
              {
                label: 'PowerShell Gallery',
                href: 'https://www.powershellgallery.com/packages/WindowsCloudPC',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} WindowsCloudPC contributors.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['powershell'],
      },
    }),
};

module.exports = config;
