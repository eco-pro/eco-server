var fs = require('fs');
var glob = require('glob');
const path = require('path');
const { spawn } = require('child_process');

const { Elm } = require('./elm.js');
const app = Elm.Top.init();
