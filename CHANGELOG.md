# 3.1.1 - 2018-05-02

Bug fix

* Fix orientation for certain JPEG images

# 3.1.0 - 2018-04-24

Updates code to match fastimage v2.1.1

* improved SVG support

# 3.0.2 - 2016-10-17

Fixes a bug,

* where local-fastimage would keep large amounts of data in memory
* where unknown file type was not reported correctly (#1)

Thanks @bertg and @sdsykes for contributing to this release

# 3.0.1 - 2016-06-02

Updating meta data in gemspec, no code changes.

# 3.0.0 - 2016-06-02

Removing support for remote images.

This way we can drop the addressable and fakeweb dependencies and eliminate a
whole class of security problems.

Also renaming to local-fastimage.
