// Simple test poller: invokes the Ruby fetcher and dumps JSON
const { exec } = require('child_process');

function runFetch() {
  console.log('Fetching latest app/build info from App Store Connect...');
  exec('ruby src/fetch_app_status.rb', (err, stdout, stderr) => {
    if (err) {
      console.error('Error executing fetch_app_status.rb:', err.message);
      if (stderr) console.error(stderr);
      process.exitCode = 1;
      return;
    }
    if (!stdout) {
      console.error('No output received from fetch_app_status.rb');
      if (stderr) console.error(stderr);
      process.exitCode = 1;
      return;
    }

    // Handle common auth/session messages gracefully
    if (stdout.includes("Couldn't find valid authentication token or credentials.")) {
      console.error('Auth error: missing App Store Connect credentials or API key env vars.');
      console.error('Ensure env vars like ITC_USERNAME/ITC_PASSWORD or SPACESHIP_CONNECT_API_* are set.');
      process.exitCode = 1;
      return;
    }
    if (stdout.includes('Available session is not valid any more. Continuing with normal login.')) {
      console.warn('Session invalid; output may retry on next run.');
    }

    try {
      const versions = JSON.parse(stdout);
      // Pretty-print raw JSON for inspection
      console.log('\n=== Raw JSON ===');
      console.log(JSON.stringify(versions, null, 2));

      // Also print a concise summary for each app/build
      console.log('\n=== Summary ===');
      versions.forEach(app => {
        console.log(`\nApp: ${app.name} (appId: ${app.appId})`);
        console.log(`  App Version: ${app.version}`);
        console.log(`  App Status: ${typeof app.status === 'string' ? app.status : (app.status && app.status.formatted ? app.status.formatted() : app.status)}`);
        if (Array.isArray(app.builds)) {
          app.builds.forEach(b => {
            console.log(`  Build: ${b.version}`);
            console.log(`    Short Version: ${b.short_version || ''}`);
            console.log(`    Build Status: ${b.status}`);
            console.log(`    TestFlight Status: ${b.beta_review_state || ''}`);
            console.log(`    Uploaded: ${b.uploaded_data || ''}`);
          });
        } else {
          console.log('  No builds array found.');
        }
      });
    } catch (parseErr) {
      console.error('Failed to parse JSON from Ruby output.');
      console.error(parseErr);
      console.error('Raw output was:\n', stdout);
      process.exitCode = 1;
    }
  });
}

runFetch();
