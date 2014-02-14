NO LONGER IN USE!
=================

REPLACED BY: r10k


pupstrap 
========

A command-line tool to simplify the use of puppet with librarian-puppet.



## Known Issues

### Malformed version number string

librarian-puppet version `0.9.10` fixed an issue that caused `pslibrarian-puppet` to error out on manifests with modules using `prerelease` versions (e.g. `1.0.0-rc1`) which is totally valid as defined by SemVer v2.0.0. The output of the failed librarian-puppet command will include a line similar to this:
```
/usr/lib/ruby/vendor_ruby/1.8/rubygems/version.rb:187:in `initialize': Malformed version number string 1.0.0-rc1 (ArgumentError)
```

To fix this just update the librarian-puppet gem (i.e. `sudo gem update librarian-puppet`)
