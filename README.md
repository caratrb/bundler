[![Version     ](https://img.shields.io/gem/v/carat.svg?style=flat)](https://rubygems.org/gems/carat)
[![Build Status](https://img.shields.io/travis/caratrb/carat/master.svg?style=flat)](https://travis-ci.org/caratrb/carat)
[![Code Climate](https://img.shields.io/codeclimate/github/caratrb/carat.svg?style=flat)](https://codeclimate.com/github/caratrb/carat)
[![Inline docs ](http://inch-ci.org/github/caratrb/carat.svg?style=flat)](http://inch-ci.org/github/caratrb/carat)

# Carat: a gem to bundle gems

Carat makes sure Ruby applications run the same code on every machine.

It does this by managing the gems that the application depends on. Given a list of gems, it can automatically download and install those gems, as well as any other gems needed by the gems that are listed. Before installing gems, it checks the versions of every gem to make sure that they are compatible, and can all be loaded at the same time. After the gems have been installed, Carat can help you update some or all of them when new versions become available. Finally, it records the exact versions that have been installed, so that others can install the exact same gems.

### Installation and usage

```
gem install carat
carat init
echo "gem 'rails'" >> Gemfile
carat install
carat exec rails new myapp
```

### Troubleshooting

For help with common problems, see [ISSUES](https://github.com/caratrb/carat/blob/master/ISSUES.md).

### Other questions

To see what has changed in recent versions of Carat, see the [CHANGELOG](https://github.com/caratrb/carat/blob/master/CHANGELOG.md).

### Contributing

If you'd like to contribute to Carat, that's awesome, and we <3 you. There's a guide to contributing to Carat (both code and general help) over in [DEVELOPMENT](https://github.com/caratrb/carat/blob/master/DEVELOPMENT.md)
