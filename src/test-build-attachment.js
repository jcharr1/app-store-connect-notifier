const poster = require('./post-update.js');
const moment = require('moment');

const appInfo = {
  name: 'Innovative Language Learning',
  appId: '1234567890',
  iconUrl: 'https://example.com/icon.png',
  version: '3.2.8',
  status: {
    formatted: () => 'Ready For Sale'
  }
};

const buildInfo = {
  version: '364',
  short_version: '4.0',
  beta_review_state: 'APPROVED',
  status: 'VALID',
  uploaded_data: moment().subtract(2, 'hours').toISOString()
};

const attachment = poster._slackAttachmentBuild(
  `The status of build version *${buildInfo.version}* for your app *${appInfo.name}* has been changed to *${buildInfo.status}*`,
  appInfo,
  buildInfo
);

console.log(JSON.stringify(attachment, null, 2));
