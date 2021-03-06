_ = require('lodash')
glob = require('glob')
xre = require('xregexp').XRegExp
assert = require('assert-plus')



# glox uses a given glob pattern and given regexp pattern
# to return an array of regexp matches.
#
# Specifically, the given regexp is matched against each path
# found by glob. Paths failing regexp matching are discarded.


# Async glox
#
# @param gpat
# @param xpat
# @param options ?({})
# @param callback ?(->)
#
# @return void
#
# @signature
#   glox(gpat, xpat)
#   glox(gpat, xpat, callback)
#   glox(gpat, xpat, options)
#   glox(gpat, xpat, options, callback)
#
module.exports = glox = (gpat, xpat, options, callback)->
  if arguments.length is 2 then       [options, callback] = [{}, ->]
  else if _.isFunction(options) then  [options, callback] = [{}, options]

  assert.string gpat, 'gpat'
  assert.string xpat, 'xpat'
  assert.object options, 'options'
  assert.func callback, 'callback'

  glob gpat, options, (er, paths)->
    return callback(er) if er
    callback(null, find_matches(paths, xpat))



# Sync glox
#
# @param gpat & xpat & options, see docs for glox()
#
# @return [match]
#
# @signature
#   glox.sync(gpat, xpat)
#   glox.sync(gpat, xpat, options)
#
glox.sync = (gpat, xpat, options={})->
  assert.string gpat, 'gpat'
  assert.string xpat, 'xpat'
  assert.object options, 'options'

  find_matches(glob.sync(gpat, options), xpat)


# Utility that runs a given regexp against
# a given array of strings.
# Returns an array of regexp matches.
find_matches = (strings, xpat)->
  assert.arrayOfString strings
  assert.string xpat

  matcher = _.partialRight(xre.exec, xre(xpat))
  matches = _.compact(_.map(strings, (str)-> matcher(str)))






# Conventions
# Meaning file-naming patterns that facilitate machine automation.
#
# Some are included with glox. They should be factored
# out into their own project once several more have been added and justify
# it. Logically they do not belong coupled with glox. It is just a matter
# of time.


glox.convention = convention = (gpat)->
  assert.string gpat

  do_transform = (acc, v, k)-> acc[k] = _.partial(v, gpat)
  _.transform(glox.convention, do_transform, {})


convention.inject = (gpat, xpat, host_or_factory, manual_trigger)->
  assert.string gpat
  assert.string xpat
  assert.bool _.isFunction(host_or_factory) or _.isPlainObject(host_or_factory)
  assert.optionalFunc manual_trigger

  _.each glox.sync(gpat, xpat, {}), (match)->
    f =
    if _.isFunction(host_or_factory)
    then host_or_factory(match)
    else host_or_factory[match[1]]

    assert.func f, 'inject function'

    do_inject = (manual_args...)->
      f_args = if _.isFunction(host_or_factory) then [f] else [f, host_or_factory]
      require(match.input)(f_args.concat(manual_args)...)

    # Expose f on injector, offers more flexibility for manual_trigger cases
    do_inject.f = f

    if manual_trigger then manual_trigger(do_inject, match) else do_inject()


convention.mocha = (gpattern, xpat, host_or_factory)->
  glox.convention.inject gpattern, xpat, host_or_factory, (do_inject, match)->
    describe _.rest(match).join(' '), ->
      # TODO ident needs to change, @it ?
      beforeEach -> @cmd = do_inject.f
      do_inject()