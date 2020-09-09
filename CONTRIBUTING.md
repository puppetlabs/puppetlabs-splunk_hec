# Releasing the module

Run a `release_prep` job with the branch set to `main` and `module_version` set to the module version that will be released

> You can access the `release_prep` job via the `Actions` tab at the repository home page

The `release_prep` job will run the `pdk release prep` command, push its changes up to the `release_prep` branch on the repo, and then generate a PR against `main` for review. Follow the instructions in the PR body to properly update the `CHANGELOG.md` file.

Once the release prep PR's been merged to `main`, run a `release` job with the branch set to `main`. The `release` job will tag the module at the current `metadata.json` version, push the tag upstream, then build and publish the module to the Forge.
