# Canvas - A module all about writing images.
Contact me on Discord.  My username is 'comt'.

### Notes
This is a work in progress.  It can be seen as mildly sloppy.  Still, this library has performance and clarity in mind.
This is also the first time I've used Github and I'm honestly too lazy to document the features here.  Please read the modules' names and functions to get an idea of what feature set we're working with.
I would love to receive any suggestions on naming or features.  Please reach out to me if there is something that can be improved or fixed.

The primary Canvas.luau module is mandatory, while the other modules are simply add-ons.
Currently, the Text add-on is entirely experimental, since I have not tested it at all.  This also goes for certain features listed in the Image module, such as the rotated images and textured triangles.

## What is it used for?
Make life easier for people who want to draw shapes and images dynamically.

## Design Philosophy
- Almost anything that incurs overhead is typically dropped in favor of performance.
- There is only one class: the Canvas class.  None other classes are created since they are unnecessary.
- Functions prefixed with "draw" will always take a function to use as a shader compiler, or in the case of the Function module, a color plotter.
- Functions prefixed with "fill" will not use shaders and will often be faster than their "draw" counterparts.
