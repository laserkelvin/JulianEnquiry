@def title = "A Betting Challenge&mdash;Julia Edition"
@def tags = ["game", "abstraction", "wsj"]
@def isblog = true
@def abstract = "Using Julia to learn about basic investing and control through a sports betting simulation."
@def showall = true
@def toc-image = "/assets/toc_images/2021/betting-problem.svg"

A few weeks ago, the [Wall Street Journal](https://www.wsj.com/articles/bet-on-baseball-learn-about-investing-11622563747) ran an interactive piece that I found incredibly thought-provoking&mdash;so much so I decided that I wanted to investigate further using Julia.

The article puts you in the context of unconventional baseball game betting: you start with some amount of money, and you bet on your team for each game of the season (out of ten). Naturally, by the end of the ten games you'd want to end up with more money than you began with! What makes this scenario unconventional is that you know the likelihood of your team winning a game, which also stays constant.

The point of the WSJ article was to "teach investors a lesson"; even if the odds of winning are tilted in your favor, _how_ you bet in each game can affect the outcome incredibly. The article introduced a strategy or "policy" for betting/investing based on information theory, which the authors mention that even large investors like Warren Buffet use to make decisions.

I thought that these ideas were intriguing, and wanted to test it out numerically outside of their limited interactive simulation. As we'll find that there are a lot more caveats to this (which also rationalizes why there every investor isn't a billionaire) equation, and in another article later, see if we can use reinforcement learning to come up with our own policy.

**Disclaimer** I'm not a finance or investing person by any stretch of the imagination, and so this is not investing advice: this notebook is purely pedagogical.
