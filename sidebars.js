/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const commandSidebar = require('./src/data/commandSidebar.json');

const sidebars = {
  docsSidebar: [
    'intro',
    'getting-started',
    {
      type: 'category',
      label: 'Guides',
      items: [
        'inventory-and-reporting',
        'snapshots',
        'reprovisioning',
        'licensing',
        'examples',
      ],
    },
    'permissions',
    'troubleshooting',
    {
      type: 'category',
      label: 'Command reference',
      link: { type: 'doc', id: 'commands/index' },
      items: commandSidebar,
    },
  ],
};

module.exports = sidebars;
