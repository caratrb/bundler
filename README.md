[![Version     ](https://img.shields.io/gem/v/carat.svg?style=flat)](https://rubygems.org/gems/carat)
[![Build Status](https://img.shields.io/travis/caratrb/carat/master.svg?style=flat)](https://travis-ci.org/caratrb/carat)
[![Code Climate](https://img.shields.io/codeclimate/github/caratrb/carat.svg?style=flat)](https://codeclimate.com/github/caratrb/carat)
[![Inline docs ](http://inch-ci.org/github/caratrb/carat.svg?style=flat)](http://inch-ci.org/github/caratrb/carat)
[![Slack       ](http://carat-slackin.herokuapp.com/badge.svg)](http://carat-slackin.herokuapp.com)

# Carat: a gem to carat gems

Carat makes sure Ruby applications run the same code on every machine.

It does this by managing the gems that the application depends on. Given a list of gems, it can automatically download and install those gems, as well as any other gems needed by the gems that are listed. Before installing gems, it checks the versions of every gem to make sure that they are compatible, and can all be loaded at the same time. After the gems have been installed, Carat can help you update some or all of them when new versions become available. Finally, it records the exact versions that have been installed, so that others can install the exact same gems.

### Installation and usage

To install (or update to the latest version):

```
gem install carat
```

To install a prerelease version (if one is available), run `gem install carat --pre`. To uninstall Carat, run `gem uninstall carat`.

Carat is most commonly used to manage your application's dependencies. For example, these commands will allow you to use Carat to manage the `rspec` gem for your application:

```
carat init
echo 'gem "rspec"' >> Gemfile
carat install
carat exec rspec
```

See [carat.io](http://carat.io) for the full documentation.

### Troubleshooting

For help with common problems, see [TROUBLESHOOTING](doc/TROUBLESHOOTING.md).

Still stuck? Try [filing an issue](doc/contributing/ISSUES.md).

### Other questions

To see what has changed in recent versions of Carat, see the [CHANGELOG](CHANGELOG.md).

To get in touch with the Carat core team and other Carat users, please see [getting help](doc/contributing/GETTING_HELP.md).

### Contributing

If you'd like to contribute to Carat, that's awesome, and we <3 you. There's a guide to contributing to Carat (both code and general help) over in [our documentation section](doc/README.md).

While some Carat contributors are compensated by Ruby Together, the project maintainers make decisions independent of Ruby Together. As a project, we welcome contributions regardless of the author’s affiliation with Ruby Together.

### Supporting

<a href="https://rubytogether.org/"><img src="https://rubytogether.org/images/rubies.svg" width="150"></a><br>
<a href="https://rubytogether.org/">Ruby Together</a> pays some Carat maintainers for their ongoing work. As a grassroots initiative committed to supporting the critical Ruby infrastructure you rely on, Ruby Together is funded entirely by the Ruby community. Contribute today <a href="https://rubytogether.org/developers">as an individual</a> or (better yet) <a href="https://rubytogether.org/companies">as a company</a> to ensure that Carat, RubyGems, and other shared tooling is around for years to come.

### Code of Conduct

Everyone interacting in the Carat project’s codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [Carat code of conduct](https://github.com/caratrb/carat/blob/master/CODE_OF_CONDUCT.md).
