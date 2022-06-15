<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [dart-version-auto-tag](#dart-version-auto-tag)
- [Usage](#usage)
- [Inputs](#inputs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# dart-version-auto-tag

This action automatically creates tags in your repository when you update your pubspec.yaml version. Use it to trigger builds automatically.

# Usage

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
      - uses: peiffer-innovations/actions-dart-version-autotag@v1.0.1
        with:
          token: ${{ secrets.TAG_TOKEN }}
```

Create another workflow that is triggered when a tag is created.

```yaml
name: Build release
on:
  push:
    tags:
    - 'v*'
jobs:
  build:
    steps:
    ...
```

Now whenever you update your pubspec version field, a version tag is automatically created.

# Inputs

| Input   | Description                                                      |
| ------- | ---------------------------------------------------------------- |
| `path`  | The path to the pubspec file to track (default: `pubspec.yaml`). |
| `token` | The GitHub access token to create tags in the repository.        |

[1]: https://github.community/t5/GitHub-Actions/Github-actions-workflow-not-triggering-with-tag-push/td-p/39685
[2]: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line
