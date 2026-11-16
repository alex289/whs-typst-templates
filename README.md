# Typst Templates for the Westfälische Hochschule

These **unofficial** templates can be used to write in [Typst](https://github.com/typst/typst) with the corporate design of the [Westfälische Hochschule](https://www.w-hs.de/).

#### Disclaimer
Please ask your supervisor if you are allowed to use typst and this template for your thesis or other documents.
Note that this template is not checked the by the Westfälische Hochschule for correctness.
Thus, this template does not guarantee completeness or correctness.

## Usage
Create a new typst project based on this template locally.
```bash
typst init @preview/modern-whs-thesis
cd modern-whs-thesis

typst init @preview/modern-whs-assignment
cd modern-whs-assignment
```
Or create a project on the typst web app based on this template.

## Customizing this template

If the predefined design of this template doesnt fit your needs, you can customize it by following these steps:

1. Download the repository of the templates
2. Copy the template folder `/templates/{type}/template` into your project.
3. Replace the import of `@preview/modern-whs-{type}` with `template/lib.typ`

## Contributing

When contributing make sure to format all files with [typstyle](https://github.com/Enter-tainer/typstyle).

```bash
# In the root directory of the repository
typstyle format-all templates
```

## Syncing a release

To prepare a new release, commit your template changes, then run:

```bash
./sync.sh
```

Select the template when prompted, or run `./sync.sh thesis` to select it directly.
Every sync automatically increases the patch version (for example, `0.6.0` to
`0.6.1`), updates `typst.toml` and the example import together, and commits those
two files in this repository before copying and committing the release in the
packages repository. It chooses a version above both the local version and the
latest version on the packages repository's refreshed `main` branch, preserving
existing releases. The source commit stays local; push this repository separately
when ready.

CI checks that every example imports its manifest's version on pushes and pull
requests. To run that check locally without syncing, use `bash scripts/check-versions.sh`.

Sync requires Git, the GitHub CLI (`gh`), and clean working trees in both repositories.
The packages checkout defaults to `~/dev/typst-packages`; set `PACKAGES_REPO` to use
another path. The script asks before pushing the packages branch.
