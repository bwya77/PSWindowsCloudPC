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
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Feature({title, description}) {
  return (
    <div className={clsx('col col--4', styles.feature)}>
      <div className={styles.featureCard}>
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <Layout
      title="WindowsCloudPC documentation"
      description="PowerShell documentation for Windows 365 Cloud PC automation">
      <header className={styles.hero}>
        <div className="container">
          <p className={styles.eyebrow}>Windows 365 automation</p>
          <Heading as="h1" className={styles.heroTitle}>
            PowerShell docs for WindowsCloudPC
          </Heading>
          <p className={styles.heroSubtitle}>
            A Docusaurus documentation site for querying, operating, and documenting Windows 365 Cloud PCs through Microsoft Graph beta APIs.
          </p>
          <div className={styles.buttons}>
            <Link className="button button--primary button--lg" to="/docs/getting-started">
              Get started
            </Link>
            <Link className="button button--secondary button--lg" to="/docs/commands/">
              Browse commands
            </Link>
            <Link className="button button--outline button--lg" href="https://www.powershellgallery.com/packages/WindowsCloudPC">
              PowerShell Gallery
            </Link>
          </div>
        </div>
      </header>
      <main>
        <section className={styles.stats}>
          <div className="container">
            <div className={styles.statsGrid}>
              <StatCard label="PowerShell Gallery version" value={stats.galleryVersion ?? stats.moduleVersion} />
              <StatCard label="Total downloads" value={formatNumber(stats.downloadCount)} />
              <StatCard label="Public commands" value={formatNumber(stats.commandCount)} />
              <StatCard label="Static test specs" value={formatNumber(stats.testSpecCount)} />
            </div>
          </div>
        </section>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              <Feature
                title="Inventory"
                description="List Cloud PCs, provisioning policies, supported regions, setting profiles, user settings, launch details, licensing allotments, and restore point snapshots."
              />
              <Feature
                title="Operations"
                description="Restart Cloud PCs, reprovision individual or policy-scoped Cloud PCs, and create restore point snapshots across single, user, policy, or tenant scopes."
              />
              <Feature
                title="Usage insights"
                description="Report active sessions, sign-in status, last active time, idle Cloud PCs, and recent remote action results."
              />
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}

