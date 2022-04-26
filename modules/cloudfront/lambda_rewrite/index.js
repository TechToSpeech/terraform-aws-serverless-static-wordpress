'use strict';

const RuleSet = require('./rules.js');

let ruleSet = new RuleSet();

module.exports.handler = (e, ctx, cb) => {
  return ruleSet
    .loadRules()
    .then(() => {
      cb(null,ruleSet.applyRules(e).res);
    });
};
