# dart-version-auto-tag

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Introduction](#introduction)
- [Usage](#usage)
- [Inputs](#inputs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

This action automatically creates tags in your repository when you update your pubspec.yaml version.  This will create the version from the pubspec but will also update the major and minor version tags to the latest commit as well.  For example, if your pubspec is version is `2.3.4+5` then this will create / update the tag: `v2.3.4+5` as well as updating the tags: `v2` and `v2.3`.  To prevent creation of the `v2` tag, set the `major` option to `false` and to prevent the minor tag, set the `minor` option to `false`.

By default this will always overwrite all tags.  You can set the `overwrite` option to `false` and then the action will abort if the full version of the tag already exists.  Using the example above, if `v2.3.4+5` already exists as a tag and the workflow is run then no tags will be run if the pubspec still has version `2.3.4+5` in it.  If `v2.3.4+5` does not exist then the `v2` and `v2.3` tags will be updated unless either or both the `major` and `minor` flags are set to `false`.


## CHANGELOG

The `CHANGELOG.md` will be read to create the message to apply to the tag.  If the version in the pubspec does not exist then the action will result in an error and no tags will created or updated.  The action will attempt to find all changes associated with the major and minor releases and combine them into the respective updated tags.  For example, take the following `CHANGELOG.md`:

```
## 1.1.2

* Bug fixes

## 1.1.1

* Performance Improvements

## 1.1.0

* Shiny new feature

## 1.0.1

* Bug fixes

## 1.0.0

* Initial Release
```

Now let's say `1.1.2` is the version that triggered the action.  The following messages will be used for each respective tag:

**`v1.1.2`**
```
## 1.1.2

* Bug fixes
```

**`v1.1`**
```
## 1.1.2

* Bug fixes

## 1.1.1

* Performance Improvements

## 1.1.0

* Shiny new feature
```

**`v1`
```
## 1.1.2

* Bug fixes

## 1.1.1

* Performance Improvements

## 1.1.0

* Shiny new feature

## 1.0.1

* Bug fixes

## 1.0.0

* Initial Release
```

### Version Detection

The changelog scanner uses the following RegEx to try to find the lines that contain a version:
```regexp
^#+\s+.*\d+\.\d+\.\d+.*
```

When a version line is detected, this RegEx is used to extract the version from the line:
```regexp
\d+\.\d+\.\d+(\+\d*)?(-[\w\d]*)?
```

A good resource for testing to make sure your CHANGELOG.md will be able to be properly parsed by the scanner is the https://regex101.com/ site.

## Usage

Setup a workflow that triggers on commit to your release branch to run this action.


```yaml
name: Version tag
on:
  push:
    branches:
      - main
    paths:
      - pubspec.yaml

jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - uses: peiffer-innovations/actions-dart-version-autotag@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input        | Description                                                                   |
|--------------|-------------------------------------------------------------------------------|
| `changelog`  | Set to `false` to ignore the changelog description (default `true`).          |
| `major`      | Set to `false` to prevent creating / updating the major tag (default `true`). |
| `minor`      | Set to `false` to prevent creating / updating the minor tag (default `true`). |
| `overwrite`  | Set to `false` to abort if the full version already exists (default `true`).  |
| `path`       | The path to the pubspec file to track (default: `.`).                         |
| `token`      | The GitHub access token to create tags in the repository.                     |

[1]: https://github.community/t5/GitHub-Actions/Github-actions-workflow-not-triggering-with-tag-push/td-p/39685
[2]: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line
