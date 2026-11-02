## Submission

First submission of aitrail.

## Test environments

* GitHub Actions: Ubuntu (R devel, release, oldrel-1), macOS (release), Windows (release).
* Local: Windows 11 x64, R 4.6.2 ucrt.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for CRAN

* Network access is used only by `ait_check_references()`, through the suggested package curl. Its example is wrapped in `\donttest{}` and checks that curl is available; the tests use recorded responses and never access the network.
* Examples and tests write only to `tempdir()`.
