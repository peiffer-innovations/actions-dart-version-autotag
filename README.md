# dart-version-auto-tag

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Introduction](#introduction)
- [Usage](#usage)
- [Inputs](#inputs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

This action automatically creates tags in your repository when you update your pubspec.yaml version.  This will create the version from the pubspec but will also update the major version tag to the latest commit as well.  For example, if your pubspec is version is "2.3.4+5" then this will create / update the tag: "v2.3.4+5" as well as updating the tag: "v2".

## Usage

Setup a workflow that triggers on commit to your release branch to run this action.

A custom GitHub access token with repo permissions needs to be created as the provided `GITHUB_TOKEN`, when used, cannot trigger other workflows. [See here][1] for more info on what this means.

To create an access token, [see here][2]. Save this token as a secret on your repo and provide it to the action like below.

```yaml
name: Version tag
on:
  push:
    branches:
      - master
jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - uses: peiffer-innovations/actions-dart-version-autotag@v2
        with:
          token: ${{ secrets.TAG_TOKEN }}
```

## Inputs

| Input        | Description                                                                      |
|--------------|----------------------------------------------------------------------------------|
| `overwrite`  | Defaults to `true`.  Set to `false` to abort if the full version already exists. |
| `path`       | The path to the pubspec file to track (default: `.`).                            |
| `token`      | The GitHub access token to create tags in the repository.                        |

[1]: https://github.community/t5/GitHub-Actions/Github-actions-workflow-not-triggering-with-tag-push/td-p/39685
[2]: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line
