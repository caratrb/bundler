# Troubleshooting common issues

Stuck using Carat? Browse these common issues before [filing a new issue](contributing/ISSUES.md).

## Permission denied when installing carat

Certain operating systems such as MacOS and Ubuntu have versions of Ruby that require elevated privileges to install gems.

    ERROR:  While executing gem ... (Gem::FilePermissionError)
      You don't have write permissions for the /Library/Ruby/Gems/2.0.0 directory.

There are multiple ways to solve this issue. You can install carat with elevated privileges using `sudo` or `su`.

    sudo gem install carat

If you cannot elevate your privileges or do not want to globally install Carat, you can use the `--user-install` option.

    gem install carat --user-install

This will install Carat into your home directory. Note that you will need to append `~/.gem/ruby/<ruby version>/bin` to your `$PATH` variable to use `carat`.

## Heroku errors

Please open a ticket with [Heroku](https://www.heroku.com) if you're having trouble deploying. They have a professional support team who can help you resolve Heroku issues far better than the Carat team can. If the problem that you are having turns out to be a bug in Carat itself, [Heroku support](https://www.heroku.com/support) can get the exact details to us.

## Other problems

First, figure out exactly what it is that you're trying to do (see [XY Problem](http://xyproblem.info/)). Then, go to the [Carat documentation website](http://carat.io) and see if we have instructions on how to do that.

Second, check [the compatibility
list](http://carat.io/compatibility.html), and make sure that the version of Carat that you are using works with the versions of Ruby and RubyGems that you are using. To see your versions:

    # Carat version
    carat -v

    # Ruby version
    ruby -v

    # RubyGems version
    gem -v

If these instructions don't work, or you can't find any appropriate instructions, you can try these troubleshooting steps:

    # Update to the latest version of carat
    gem install carat

    # Remove user-specific gems and git repos
    rm -rf ~/.carat/ ~/.gem/carat/ ~/.gems/cache/carat/

    # Remove system-wide git repos and git checkouts
    rm -rf $GEM_HOME/carat/ $GEM_HOME/cache/carat/

    # Remove project-specific settings
    rm -rf .carat/

    # Remove project-specific cached gems and repos
    rm -rf vendor/cache/

    # Remove the saved resolve of the Gemfile
    rm -rf Gemfile.lock

    # Uninstall the rubygems-carat and open_gem gems
    rvm gemset use global # if using rvm
    gem uninstall rubygems-carat open_gem

    # Try to install one more time
    carat install
