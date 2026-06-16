import clsx from 'clsx';
import Heading from '@theme/Heading';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import styles from './index.module.css';
import stats from '../data/stats.json';

function formatNumber(value) {
  if (value === null || value === undefined) {
    return 'n/a';
  }
  const number = Number(value);
  return Number.isFinite(number) ? number.toLocaleString() : String(value);
}

function StatCard({label, value}) {
  return (
    <div className={styles.statCard}>
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function Feature({title, description, to}) {
  return (
    <div className={clsx('col col--4', styles.feature)}>
      <Link className={styles.featureCard} to={to}>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </Link>
    </div>
  );
}

const features = [
  {
    title: 'Inventory and reporting',
    description: 'List Cloud PCs, users, provisioning policies, launch details, usage status, and recent remote actions.',
    to: '/docs/inventory-and-reporting',
  },
  {
    title: 'Snapshots',
    description: 'View restore points or create snapshots by Cloud PC, user, provisioning policy, or tenant-wide scope.',
    to: '/docs/snapshots',
  },
  {
    title: 'Reprovisioning',
    description: 'Reprovision individual Cloud PCs or policy-scoped fleets with WhatIf, Force, and exclusion support.',
    to: '/docs/reprovisioning',
  },
  {
    title: 'Licensing',
    description: 'Read cloud licensing allotments, consumed units, available units, services, and subscription metadata.',
    to: '/docs/licensing',
  },
  {
    title: 'Permissions',
    description: 'Understand the Microsoft Graph delegated scopes each command uses and when write scopes are requested.',
    to: '/docs/permissions',
  },
  {
    title: 'Command reference',
    description: 'Browse generated documentation for every public command in the module.',
    to: '/docs/commands/',
  },
];

export default function Home() {
  return (
    <Layout
      title="WindowsCloudPC documentation"
      description="PowerShell documentation for Windows 365 Cloud PC automation">
      <header className={styles.hero}>
        <div className="container">
          <div className={styles.heroGrid}>
            <div>
              <p className={styles.eyebrow}>Windows 365 PowerShell</p>
              <Heading as="h1" className={styles.heroTitle}>
                Manage Cloud PCs from the shell
              </Heading>
              <p className={styles.heroSubtitle}>
                WindowsCloudPC wraps Microsoft Graph beta endpoints in practical PowerShell commands for inventory, usage reporting, snapshots, reprovisioning, and licensing.
              </p>
              <div className={styles.buttons}>
                <Link className="button button--primary button--lg" to="/docs/getting-started">
                  Get started
                </Link>
                <Link className="button button--secondary button--lg" to="/docs/commands/">
                  Command reference
                </Link>
              </div>
            </div>
            <div className={styles.quickStart}>
              <div className={styles.windowChrome}>
                <span />
                <span />
                <span />
              </div>
              <pre>
                <code>{`Install-Module WindowsCloudPC -Scope CurrentUser
Connect-CloudPC

Get-CloudPCUsage |
  Sort-Object DaysSinceLastSignIn -Descending |
  Format-Table CloudPcName,UsageStatus,DaysSinceLastSignIn`}</code>
              </pre>
            </div>
          </div>
        </div>
      </header>
      <main>
        <section className={styles.stats}>
          <div className="container">
            <div className={styles.statsGrid}>
              <StatCard label="Gallery version" value={stats.galleryVersion ?? stats.moduleVersion} />
              <StatCard label="Total downloads" value={formatNumber(stats.downloadCount)} />
              <StatCard label="Commands" value={formatNumber(stats.commandCount)} />
              <StatCard label="Test specs" value={formatNumber(stats.testSpecCount)} />
            </div>
          </div>
        </section>
        <section className={styles.features}>
          <div className="container">
            <div className={styles.sectionHeader}>
              <Heading as="h2">Documentation by task</Heading>
              <p>Start with the workflow you need, then jump into generated command help when you need parameters and examples.</p>
            </div>
            <div className="row">
              {features.map((feature) => (
                <Feature key={feature.title} {...feature} />
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
