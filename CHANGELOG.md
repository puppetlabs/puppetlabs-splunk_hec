# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [Unreleased](https://github.com/puppetlabs/puppetlabs-splunk_hec)

[Current Diff](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v1.0.1..main)

 ## [v1.0.1](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v1.0.1) (2021-10-04)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v1.0.0..v1.0.1)

### Fixed

- Removed hardcoded certname in util_splunk_hec template. [#149](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/149)
- Updated sourcetype from common_events to pe_event_forwarding in util_splunk_hec template. [#149](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/149)

### Added

- Added `event_types` parameter to limit the event types sent to Splunk. [#152](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/152)

## [v1.0.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v1.0.0) (2021-09-29)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.10.0...v1.0.0)

### Added

- Event Forwarding Processor to handle events from PE Event Fowarding. [#142](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/142)

## [v0.10.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.10.0) (2021-08-23)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.9.2...v0.10.0)

### Added

- Ignore System CA Certificate Store. [#137](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/137)

## [v0.9.2](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.9.2) (2021-08-02)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.9.1...v0.9.2)

### Fixed

- Fixed sourcetypetime to allow metrics to be sent without issue. [#135](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/135)

- Module metadata now supports latest versions of Puppet and Puppets Metrics Collector

## [v0.9.1](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.9.1) (2021-07-07)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.9.0...v0.9.1)

### Fixed

- Timestamp now matches timestamp value in the console [#130](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/130)

## [v0.9.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.9.0) (2021-06-29)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.8.1...v0.9.0)

### Fixed

- Puppet open source compatibility [\#76](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/76) Thanks [@southalc](https://github.com/southalc)

- Deprecation warning only when report parameter defined [\#85](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/85)

### Added

- Added array resource format option [\#40](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/40)

- Added Puppet Alert Actions documentation to README.md [\#115](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/115) Thanks [@coreymbe](https://github.com/coreymbe)

- Added splunk_hec disabling feature [\#120](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/120)

### Changed

- Project issues URl changed in metadata to point to JIRA to create tickets instead of at github to create issues [\#62](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/62)

- Switch to the `pe_ini_subsetting` resource for adding the report processor setting [\#51](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/51)

### Deprecated

- 'report' setting is now dynamically calculated. [\#49](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/49)


## [v0.8.1](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.8.1) (2020-05-11)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.8.0...v0.8.1)

### Fixed

- Replace relative docs links with static links [\#45](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/45) ([gsparks](https://github.com/gsparks))

## [v0.8.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.8.0) (2020-05-07)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.7.1...v0.8.0)

### Fixed

- fix single quote issue in classifier [\#42](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/42) ([mrzarquon](https://github.com/mrzarquon))
- \(PIE-178\) Parse line-delimited JSON metrics [\#39](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/39) ([Sharpie](https://github.com/Sharpie))
- PIE-178 Multiple Metrics in stdin [\#36](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/36) ([mrzarquon](https://github.com/mrzarquon))

## [v0.7.1](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.7.1) (2019-07-01)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/v0.7.0...v0.7.1)

### Fixed

- Fixes metrics uploading on splunk\_hec application [\#30](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/30) ([mrzarquon](https://github.com/mrzarquon))

## [v0.7.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/v0.7.0) (2019-06-25)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/0.7.0...v0.7.0)

## [0.7.0](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/0.7.0) (2019-06-17)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-splunk_hec/compare/0.6.0...0.7.0)

### Added

- Setup for github-changelog-generator [\#21](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/21) ([HelenCampbell](https://github.com/HelenCampbell))

### Fixed

- Adds troubleshooting documentation [\#22](https://github.com/puppetlabs/puppetlabs-splunk_hec/pull/22) ([mrzarquon](https://github.com/mrzarquon))

## 0.6.0
(2019/06/13)

### Changed
- The splunk_hec module now supports customizing the `fact_terminus` and `facts_cache_terminus` names in the custom routes.yaml it deploys. If you are using a different facts_terminus (ie, not PuppetDB), you will want to set that parameter. Please note that this will come with a breaking change in functionality - Switches to the fact terminus cache setting via routes.yaml to ensure compatibility with CD4PE, see Fact Terminus Support for guides on how to change it.

## 0.5.0
(2019/06/11)

### Added
- Advanced configuration for puppet:summary, puppet:facts and puppet:metrics to allow for the support of multiple indexes
- Additional documentation updates
- Added support for individual sourcetype urls
- Added ability to define multiple hec tokens on a sourcetype basis
- Addition of basic acceptance testing using Litmus
- The module is now under the power of the PDK
- Addition of the `saved_report` flag for the splunk_hec application - Allows the user to test some of the splunk_hec functionality, submits the result directly to the splunk configuration
- Addition of the splunk_hec puppet face/app allowing for a cat json | puppet splunk_hec like workflow. The primary functionality of this code is to enable sending pe metrics data to Splunk using the current CS best practices for collecting the CS data.
- Major changes to module were done to enable the Fact Terminus:
  - util/splunk_hec.rb created for common access methods
  - consistent info and error handling for both reports and facts
  - performance profile support for Fact Terminus
  - Documentation updated with guide and default facts listed
  - Module updated to optionally manage reports setting in puppet.conf
  - Module updated to add new parameters and template values
  - Fact collection time added to puppet report processor
  - SSL handling and documentation improved

### Fixed
- Minor fixes to output dialog

### Changed
- url parameter now expects a full URI of https://servername:8088/services/collector

## 0.4.1

- A small maintenance release to fix some broken links in metadata

## 0.4.0

Initial release

* SSL checking of target Splunk HEC is possible
* Submits Puppet Summary report
* Tasks for Bolt Apply and Bolt Result included
* Example Plans for above included


\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
