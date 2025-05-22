/* This page is not currently used */

const page = new WebPage(); let idx = 0; let loadInProgress = false;
const system = require('system');

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onLoadStarted = function() {
  loadInProgress = true;
};

page.onLoadFinished = function() {
  loadInProgress = false;
};

page.onError = function(msg, trace) {
};

const args = system.args;
if (args.length < 6) {
  console.log('USAGE: phantomjs get_report.js <port> <output_pdf> <username> <password> <num_hours>');
  phantom.exit(1);
}
const port = args[1];
const output = args[2];
const user = args[3];
const password = args[4];
const num_hours = args[5];
const address = 'http://localhost:'+port+'/lua/login.lua';

const steps = [
  function(address, output) {
    page.open(address);
  },
  function(address, output, user, password, num_hours) {
    page.evaluate(function(user, password, num_hours) {
      const arr = document.getElementsByClassName('form-control');
      let i;

      for (i = 0; i < arr.length; i++) {
        console.log(arr[i].name);
        if (arr[i].name == 'user') arr[i].value = user;
        if (arr[i].name == 'password') arr[i].value = password;
        if (arr[i].name == 'referer') arr[i].value = '/lua/pro/report.lua?numhours='+num_hours+'&printable=true';
        // if (arr[i].name == "referer") arr[i].value = "/lua/flows_stats.lua";
      }
    }, user, password, num_hours);
  },
  function() {
    page.evaluate(function() {
      const arr = document.getElementsByClassName('form-signin');
      let i;

      for (i = 0; i < arr.length; i++) {
        if (arr[i].getAttribute('method') == 'POST') {
          console.log(arr[i].action);
          arr[i].submit();
          return;
        }
      }
    });
  },
  function(address, output) {
    const size = {format: 'A4', orientation: 'portrait', margin: '1cm'};
    page.viewportSize = {width: 1920, height: 1080};
    // page.viewportSize = { width: 600, height: 600 };
    page.paperSize = size;
    page.render(output);
  },
  function() {
    phantom.exit();
  },
];


interval = setInterval(function() {
  if (!loadInProgress && typeof steps[idx] == 'function') {
    steps[idx](address, output, user, password, num_hours);
    idx++;
  }
}, 1000);
