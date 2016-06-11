# NeHe OpenGL Tutorials Elixir

This is a fork of [knewter's port](https://github.com/knewter/nehe_opengl_elixir)
of [asceth's port](https://github.com/asceth/nehe_erlang) of the legacy
[Neon Helium OpenGL tutorials](http://nehe.gamedev.net).

It has been cleaned up in order for it not to include any specific playground
code in the `master` branch. Use it as a starting point if you want to see how
some of the NeHe tutorials could be done in Elixir. I did.

## Play

```sh
iex -S mix
```

```elixir
gc = GameCore.start_link
GameCore.load(gc, Lesson02)
```

You can edit the `lesson02.ex` module and recompile it in the shell, and it will
live-update, so that's cool.
