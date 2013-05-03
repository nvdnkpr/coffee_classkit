cs        = require 'coffee-script'
_         = require 'underscore'
flow      = require 'flow-coffee'
classkit  = require './coffee_classkit'

callbacks =
  key: (name) -> "_#{name}_callbacks"
  keyCompiled: (name) -> "_#{name}_callbacks_compiled"

  define: (klass, name) ->
    classkit.instanceVariable @, callbacks.key name
    klass[@key name] = []

  add: (klass, name, args...) ->
    [options, filter] = classkit.findOptions args
    item    = [[filter, @normalizeOptions options]]
    origin  = klass[@key name]
    klass[@key name] = if options.prepend
     item.concat origin
    else
      origin.concat item
    @compile klass, name

  # options not supported
  skip: (klass, name, args...) ->
    [options, filter] = classkit.findOptions args
    klass[@key name] = if filter
      klass[@key name].filter ([item, options]) -> item != filter
    else
      []
    @compile klass, name
    @

  compile: (klass, name) ->
    klass[@keyCompiled name] = _.flatten(
      for [filter, options] in klass[@key name]
        if options.if.length or options.unless.length
          [@compileOptions(options), filter]
        else
          [filter]
    )

  normalizeOptions: (options) ->
    return options if typeof options is 'function'
    if:     _.compact _.flatten [options.if]
    unless: _.compact _.flatten [options.unless]

  compileOptions: (options) ->
    return options if typeof options is 'function'
    return options.when if options.when
    clauses = options.if
    clauses.push "!(#{options.unless.join ' and '})" if options.unless.length
    # OPTIMIZE: replace args... with err
    eval cs.compile """
      (args..., cb) ->
        cb.skip() unless #{clauses.join ' and '}
        cb.next args...
    """, bare: true

  run: (klass, context, name, callback, error) ->
    return callback() unless (chain = klass[@keyCompiled name])?.length
    (new flow
      context: context
      blocks: chain.concat [callback]
      error: error
    ) null
    @

module.exports = callbacks
