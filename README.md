AQT is yet another quest tracker addon. No, not the kind that will tell you where to go or anything. It merely displays your progress on quests you have in your log. It will only use data supplied by the API, as such, there are no plans to include information on questgiver locations or quest targets or the like.

What it will do is:

* Show a list of the quests in your log, and their status.
* Optionally colour by difficulty/completion. Fully configurable with either a HSV or RGB gradient.
* Optionally show quest tags/levels.
* Configurable sorting, with more options to be added.
* Sounds, if you're into that kind of thing. I am. Defaults to faction-based sounds, but can be reconfigured. Makes use of LibSharedMedia.
* Direct quest updates via LibSink, and optionally suppress the standard errorframe update.

Apart from improving on the current functionality, some of which I will admit is somewhat lackluster, future plans include:

* Ability to select quests for tracking via a custom-made questlog. (I try to avoid interacting with the standard interface as much as possible. If you even look at a part of it the wrong way: taint.)
* Keep track of quest progress within your party. Would only work for party members running the addon. May make it library-based.
* Make it more modular to accomodate for things like achievements, so that a retail version could also be considered. Or other addons display things in the frame, should they so wish. This is currently a lower priority.
* Probably more. If it isn't here, I might've just forgotten about it.

Please use the [Issue Tracker](https://github.com/Aiue/AQT/issues) on GitHub for bug reports or feature requests.

Translators wanted! Let me know if you want to contribute with translations!