# MagicCardSearch

A native iOS app that understands Scryfall syntax and makes it ergonomic, or whatever.

## Building

There is a separate Xcode build target for [Citron](https://github.com/roop/citron/) and the grammar file it compiles. This is hardcoded to use `SDKROOT=macosx` so it works when the run target is iPhones.

(If you delete the generated `.swift` file, you will need to run a build twice in a row, since I don't know how to Xcode and can't figure out how to tell it to add the file to the same build that's currently running instead of waiting for it to notice on disk for the next build. Then I wouldn't have to commit it.)
