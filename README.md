# ArchivesSpace Custom Reports

A plugin containing custom reports for use in ArchivesSpace

## Description/Summary

Reports in ArchivesSpace are defined as ruby classes.  There are several relevant classes, the code for which is defined in various files here: https://github.com/archivesspace/archivesspace/tree/master/backend/app/model/reports

## Structure/Making New Reports

All the reports defined here use the simplest interface, defined here: https://github.com/archivesspace/archivesspace/blob/master/backend/app/model/reports/abstract_report.rb

In order to create a new report, you need to add the following:

1. a new report class, inheriting from `AbstractReport`, with:
  - a call to `register_report`, listing any parameters the report takes
    - parameters are passed into register report as an array, with each parameter being an array of:
      - parameter's name
      - type of parameter, which is a COMPLICATED ISSUE but String is safe
      - description of param, which shows in the interface
  - a `query_string` method that returns the SQL statement to generate the report
  - IF the report takes parameters, an initialize method that calls super and then sets variables based on the params
  
2. Localization values for the report in question, under [LANG] -> `reports` -> [snake_case_version_of_classname] with the following keys required:

| *Key* | *Description* |
| --- | --- |
| `title` | the user-visible name of the report |
| `description` | user-visible description of the report |
| `identifier_prefix` | what section of the reports UI it will be located in |

If the report is meant to be per-repo, or has parameters, the query_string method should insert them into the query string, being careful to use db.literal to escape values as necessary. 

Here's an example of one of the simplest cases, a report with no parameters that doesn't filter by the user's repository:

- Class: https://github.com/pobocks/custom_aspace_reports/blob/master/backend/model/container_profiles.rb
- Locale values: https://github.com/pobocks/custom_aspace_reports/blob/193f8b7e2f07738cd5cd8bbcc461d3e602c859a6/frontend/locales/en.yml#L11 (lines 11-14)

And here's a more complex example that uses a parameter:

- Class: https://github.com/pobocks/custom_aspace_reports/blob/master/backend/model/resource_top_containers.rb
- Locale values: https://github.com/pobocks/custom_aspace_reports/blob/master/frontend/locales/en.yml#L26 (lines 26-29)


