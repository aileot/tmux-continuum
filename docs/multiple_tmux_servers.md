### Behavior when running multiple tmux servers

(This is safe to skip if you're always running a single tmux server.)

If you're an advanced tmux user, you might be running multiple tmux servers at
the same time. Maybe you start the first tmux server with `$ tmux` and then
later another one with e.g. `$ tmux -S/tmp/foo`.

You probably don't want the second tmux server using `/tmp/foo` to auto-restore
the same environment. You also probably don't want multiple servers auto-saving
into the same resurrect directory.

This plugin handles multiple servers by checking each server's
`@resurrect-dir`.

In the above example, if both servers use the same `@resurrect-dir`, the first
server started with `$ tmux` gets auto-restore (if enabled) and auto-save. The
later server started with `$ tmux -S/tmp/foo` gets neither.

If tmux servers use different `@resurrect-dir` values, they can auto-save
independently because they no longer target the same location.

An example to keep a separate save directory for each socket:

```tmux
set-option -sF @socket-name "#{b:socket_path}"
set-option -gF @resurrect-dir "$HOME/.local/state/tmux/resurrect/#{@socket-name}"
```
