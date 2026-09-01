'use strict'

const path = require('path')
const preload = path.join(__dirname, 'business-priority-preload.js')
const current = String(process.env.NODE_OPTIONS || '').trim()
const flag = '--require=' + preload
if (current.indexOf(flag) < 0) process.env.NODE_OPTIONS = (current ? current + ' ' : '') + flag

require('./business-priority-preload.js')
require('./server-f17.js')
