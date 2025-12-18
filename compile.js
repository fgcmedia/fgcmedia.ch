var fs = require('fs');

// AccountName = process.env.ACCOUNT_NAME || "Developer";
// HostName = process.env.RENDER_EXTERNAL_HOSTNAME || "https://render.com";

var data = fs.readFileSync('index.html', 'utf-8');

// var newValue = data.replace(/{\$AccountName}/gim, AccountName).replace(/{\$HostName}/gim, HostName);

fs.writeFileSync('index.html', data, 'utf-8');
