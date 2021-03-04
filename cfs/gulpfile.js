'use strict';
let gulp = require('gulp');
let install = require('gulp-install');
let rename = require('gulp-rename');
let replace = require('gulp-replace');
let rimraf = require('gulp-rimraf');
let path = require('path');
let cf = require('cf-utils');
let inquirer = require('inquirer');

cf.init(require('./config'));

gulp.task('install', function() {
  return gulp.src(
      path.join(__dirname, 'package.json'),
      path.resolve(__dirname, cf.config.API.SOURCE_DIR, 'package.json'))
    .pipe(install());
});

gulp.task('deploy_core_stack', function () {
  cf.logger.info('Creating core infrastructure...');
  return cf.cloudFormation.upsertStack(
    cf.config.getResourceName(cf.config.STACK.CORE.name),
    cf.config.STACK.CORE.script,
    [
      {ParameterKey: "ResourcePrefix",       ParameterValue: cf.config.getResourcePrefix()},
      {ParameterKey: "Project",              ParameterValue: cf.config.PROJECT},
      {ParameterKey: "ProjectVersion",       ParameterValue: cf.config.PROJECT_VERSION},
      {ParameterKey: "EnvironmentName",      ParameterValue: cf.config.ENVIRONMENT_STAGE},
      {ParameterKey: 'AcsIdentityUserPool',  ParameterValue: cf.config.ACS_IDENTITY_USER_POOL}
    ]);
});

gulp.task('delete_core_stack', function() {
  cf.logger.info('Deleting core infrastructure...');
  return cf.cloudFormation.deleteStack(cf.config.getResourceName(cf.config.STACK.CORE.name));
});
