# Revolver

Given a number of tests, Revolver uses genetic algorithms to write, or rather try to write, a Ruby program that satisfies those tests.

## Why on earth

FUN!

## Installation

Add this line to your application's Gemfile:

    gem 'revolver'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install revolver

## Usage

```ruby
require 'revolver'

# Write a program that returns a number between -500 and 500.
Revolver.new
  .return_value_should(-> retval { retval > -500 })
  .return_value_should(-> retval { retval < 500 })
  .go!
```

If `ENV['VERBOSE']` is set, it will spit out all the programs of all the
generations as they are being written.

## Who's this

This was made by [Josep M. Bach (Txus)](http://blog.txus.io) under the MIT
license. I'm [@txustice][twitter] on twitter (where you should probably follow
me!).
