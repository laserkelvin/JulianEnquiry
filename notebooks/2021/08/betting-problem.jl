### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 885c1012-f0a2-11eb-0dcf-05079863473a
begin
	using Random, Distributions, Plots, PlutoUI
	using StatsBase, ColorSchemes
end

# ╔═╡ 4706db38-791f-44b2-849c-ebc758f64788
md"""# A Baseball Betting Challenge - Julia Edition

A few weeks ago, the [Wall Street Journal](https://www.wsj.com/articles/bet-on-baseball-learn-about-investing-11622563747) ran an interactive piece that I found incredibly thought-provoking - so much so I decided that I wanted to investigate further using Julia.

The article puts you in the context of unconventional baseball game betting: you start with some amount of money, and you bet on your team for each game of the season (out of ten). Naturally, by the end of the ten games you'd want to end up with more money than you began with! What makes this scenario unconventional is that you know the likelihood of your team winning a game, which also stays constant.

The point of the WSJ article was to "teach investors a lesson"; even if the odds of winning are tilted in your favor, _how_ you bet in each game can affect the outcome incredibly. The article introduced a strategy or "policy" for betting/investing based on information theory, which the authors mention that even large investors like Warren Buffet use to make decisions.

I thought that these ideas were intriguing, and wanted to test it out numerically outside of their limited interactive simulation. As we'll find that there are a lot more caveats to this (which also rationalizes why there every investor isn't a billionaire) equation, and in another article later, see if we can use reinforcement learning to come up with our own policy.

**Disclaimer** I'm not a finance or investing person by any stretch of the imagination, and so this is not investing advice: this notebook is purely pedagogical.
"""

# ╔═╡ 571bf26e-5c81-46cc-a329-54bb3afe96bb
md"""With that out of the way, we can start working on building the code.

For the first part, we're going to reproduce the context/environment we'll be working in: we have a wallet that holds some amount of money, and with each round, we need to be able to bet what's in our wallet, check if we win or not according to some probability, and then update our wallet.

First, we'll implement a `struct` that represents our "wallet", i.e. keep track of how much money we have:
"""

# ╔═╡ 04c4215a-46a7-47bf-bea1-880a98651c75
begin
	mutable struct Wallet
		value::Integer
		Wallet(value=50) = new(value)
	end
end

# ╔═╡ fe87f0be-14c4-45e9-a60a-6bf1b7294930
md"""
This sets up an object that will help us keep track of how much money we have available to us.
"""

# ╔═╡ eb075aa1-176b-4a16-9443-5fa37a37c1b8
begin
	function increment_wallet!(wallet, amount)
		wallet.value += amount
	end
end

# ╔═╡ 2afc2ab8-aae6-4910-a5cc-29fd852a2ab3
md"""
Now we have a function that will help us control the amount of money we have: the `!` is a Julian custom to indicate an impure function (i.e. one that modifies the value of something inplace).
"""

# ╔═╡ 30088191-79c0-483c-b3c5-d44101393ad4
begin
	function bet_amount!(wallet, amount; p=0.5)
		# I recommend responsible gaming :wink:
		@assert amount <= wallet.value
		change = rand(Binomial(1, p)) == 1 ? amount : -amount
		increment_wallet!(wallet, change)
		@show "Bet: $amount, Change: $change, Wallet: $(wallet.value)."
	end
end

# ╔═╡ 212791cd-1e0b-429f-85cf-9ce462579f1a
md"""
For our betting function, the three lines simply check that we have enough money to bet (we don't want to get into debt!), check if we won, and then update our wallet.

The middle step can be broken down a little bit more, given that it's a nice one-liner in Julia:

```julia
change = rand(Binomial(1, p)) == 1 ? amount : -amount
```

To determine if we won or not, we are essentially flipping a coin (i.e. a Binomial test) that has probability $p$ in success, and the ` == 1 ? amount : -amount` simply checks if the result of the test is successful, in which we then set the variable `change = amount`. If not, `change = -amount`.

"""

# ╔═╡ 82c0d04e-f38f-4b8f-89cb-935b3887f8ab
md"""
To ensure that our trials are reproducible, we're going to set a random number generator seed here:
"""

# ╔═╡ e60de62e-4307-41fe-934f-42fe1eeb6e07
Random.seed!(1066012);

# ╔═╡ 40db13aa-502d-429e-bb3c-120c42370923
md"""Now to build some interactivity: with `Pluto` notebooks, we can bind HTML elements to Julia variables. This is made simpler using `PlutoUI`, which provides an `@bind` macro.
"""

# ╔═╡ c5ef6a98-aa78-4219-81d2-fbd3c1e574e4
md"""
Set the amount of money we start off with:
$(@bind start_amount Slider(5:100, default=50, show_value=true))
"""

# ╔═╡ 41715d6a-ff67-4f7a-a13c-5a5c74a8c71b
wallet = Wallet(start_amount)

# ╔═╡ c0cdc755-6b8d-4bdb-8644-258028694d64
# let's add some money to the wallet
increment_wallet!(wallet, 5)

# ╔═╡ decc4e31-b1b1-4b46-bb79-5630d6fe06f6
# if we take money away
increment_wallet!(wallet, -5)

# ╔═╡ f4bc3369-70ca-4959-bc44-f75094cb5f25
md"""We'll also include a tunable likelihood of winning:
$(@bind winning_likelihood Slider(0.:0.01:1., default=0.6, show_value=true))
"""

# ╔═╡ b685cc54-d178-4753-9ab9-819f280e850f
bet_amount!(wallet, 5; p=winning_likelihood)

# ╔═╡ eacf9e94-966c-4042-91da-b4499e206e7b
wallet.value

# ╔═╡ 074cb90c-2ae2-44c1-87f5-6b316017ac2b
md"""Now we have the core ingredients we need: we have our wallet to bet out of, UI elements to control some conditions, and a function that will control the betting and book keeping for us.

With these parts in place, we can start to think a little more about betting strategy. Here, we'll talk about the "lesson" the WSJ article tries to teach investors, which is the Kelly criterion.
"""

# ╔═╡ 5eda98de-f020-4cec-b75b-845ecf34a795
md"""## All gas, no brakes

One way of optimizing the overall return is using the so-called Kelly criterion/strategy/bet; Daniel Kelly details it in this [seminal paper](https://www.princeton.edu/~wbialek/rome/refs/kelly_56.pdf) in which he builds on top of the Information Theory framework pioneered by Claude Shannon. Before we go into that strategy, we have to discuss a little bit about alternative approaches.

In Kelly's paper, he defines an expression for the exponential growth rate of our wallet (that's got a nice ring to it). In order to maximize the growth rate, and therefore the amount of money we win, we naturally have to bet all of our money in every single round. If we assume our bets compound without possibly of failure, then the growth rate $G$ depends on the number of times you bet ($N$), the starting amount ($V_0$), and your reward at any given point ($V_N$):

$$G = \lim_{n \rightarrow \infty} \frac{1}{N} \log \frac{V_N}{V_0}$$

Now this doesn't match our scenario exactly: we are not guaranteed a win, and instead we have some probability $p$ of success. Then, the expected value after $N$ bets, $\langle V_N \rangle$, assuming that we go all in each time is given by:

$$\langle V_N \rangle = (2p)^NV_0$$

An interesting conclusion written by Kelly, and omitted in the WSJ article, is that in the limit of infinite bets, $\langle V_N \rangle$ will approach zero (as $p$ compounded by $p$ becomes increasingly small). To check this, let's run this exact experiment:
"""

# ╔═╡ 8112fecc-9808-4989-ab1f-d3a6acee8a9e
begin
	"""Function that will repeatedly bet your entire wallet `n` times
	with probability `p` of winning. The history of your wallet is
	returned as a vector.
	"""
	function i_like_to_live_dangerously!(wallet; n=100, p=0.5)
		values = []
		for i in 1:n
			bet_amount!(wallet, wallet.value; p=p)
			push!(values, wallet.value)
		end
		return values
	end
end		

# ╔═╡ 040225b7-dbd2-4378-af4d-b2154ef1dae6
# artificially set our wallet value to 100 dollars
all_in_wallet = Wallet(100)

# ╔═╡ f049a6a6-1e87-411b-9c41-c2e03e0589a2
series = i_like_to_live_dangerously!(all_in_wallet; n=10, p=winning_likelihood);

# ╔═╡ b8eb2a1a-2d5b-4dab-a0b1-ecf51ab6a54e
series

# ╔═╡ 4646111a-9e92-4913-aadf-c31fda286007
md"""You might be wondering if there's something wrong with the code; we lost all our money at the very beginning! Let's repeat this experiment many times, and visualize the final results.
"""

# ╔═╡ 59110606-9d88-4fb1-829c-1efe1ef28035
begin
	function all_in_experiments(; n=100, p=0.5)
		results = []
		for i in 1:n
			wallet = Wallet()
			series = i_like_to_live_dangerously!(wallet; n=10)
			push!(results, series)
		end
		return results
	end
end

# ╔═╡ ccc48705-aee9-4dd9-9e04-e188a3475276
@bind num_trials Slider(100:1000, show_value=true, default=300)

# ╔═╡ df26cd51-7a1b-4893-804f-4a54237f95c6
results = all_in_experiments(; n=num_trials, p=winning_likelihood);

# ╔═╡ 5ed2f2a7-fa82-40c0-bb6a-c70131c31142
plot(results, legend=false, alpha=0.2, xlabel="Round", ylabel="Value / \$", color=:black, title="All gas no brakes policy trajectories")

# ╔═╡ e3c4bfdc-f3d7-4523-ab22-d56efa3cc9df
md"""From the above, we see that in a some trials we manage to win consecutively, and depending on your initial conditions, you may even be lucky enough to see one trial walk away with all their earnings!

To put it into another perspective, let's take a look at how much money we end up with by the end of the season for each trial:
"""

# ╔═╡ c42b146d-2b9f-4741-abe2-ce00b7b207cc
# grab the last element of each trial
final_amounts_dangerous = map(x -> x[end], results);

# ╔═╡ 336e2b2c-fd55-4076-a44b-08b448ce1224
danger_hist = plot(histogram(final_amounts_dangerous, bins=range(0,1_000; length=100)), xlabel="Final amount / \$", ylabel="Counts", legend=false, title="Amounts after $num_trials trials, with 10 games each")

# ╔═╡ 3ec8c8db-ad0f-4347-8994-cb6366bda92c
md"""## A better strategy

Clearly, betting all your money in every single round is not a great strategy, unless you're trying to race to the bottom. Instead, we would want an approach that will maximize our chance of not having a zero money at the end of the season, whilst also increasing the amount we end with.

The so-called Kelly strategy encodes this strategy in terms of the fraction of money ($A$) you should bet each round, providing you know what the odds of winning are and your win/loss ($W/L$) record:

$$A=p - \frac{L(1-p)}{W}$$

Intuitively, this expression says you should bet the most when you're winning ($W\rightarrow\infty$), although you should _never bet all of your money_, as the maximum value would be $p$. On the other hand, when you've been losing a bunch, you should probably hedge your bets.
"""

# ╔═╡ de21be4a-aee3-4021-9a1d-55984bcd5b9e
begin
	"""Calculate the Kelly criterion, which tells you how much to invest
	given your win/loss history, and a known probability of winning.
	
	The resulting value is clamped between 0 and 1
	"""
	function kelly_bet(p, L, W)
		A = p - ((1 - p) / (W / L))
		return clamp(A, 0f0, 1f0)
	end
end

# ╔═╡ f7108217-d86d-42b0-9620-3a88e30eb1b0
md"""What does this function actually look like? We can evaluate it on a grid of wins and losses pretty easily with standard Julia syntax for 2D functions: take one of the dimensions and transpose the data, and when you broadcast the function with `.`, it will evaluate it elementwise for each element in your "grid", without ever having to actually generate the grid!
"""

# ╔═╡ 8ba32880-2378-4f3c-b67c-98c627d5e38f
L, W = 1:30, (1:30)';

# ╔═╡ d038fdd0-34e6-4195-b3e2-d3cab1d8ed21
A = kelly_bet.(winning_likelihood, L, W);

# ╔═╡ 4364aeda-ca17-47b7-90fc-9d6355405694
begin
	contourf(L, W', A, seriescolor=:GnBu_4, xlabel="# Wins", ylabel="# Losses", title="Fraction to bet, p=$winning_likelihood")
	plot!(1:30,1:30, lw=2.5, color=:black, legend=false, alpha=0.3, ls=:dash)
end

# ╔═╡ 60123607-3d57-4af9-a9e6-3fa2e69cd8be
md"""The straight line is just used to guide the eye, where we have an equal number of wins and losses. According to this betting strategy/policy, the more you win, the more you could bet. The important thing to gather from this: _it is never wise to bet all your money in a single game_. If you don't take anything else away from this piece, learn this!
"""

# ╔═╡ 619c9c0c-00f7-45a3-abc9-5d03f23d4e34
md"""Now to automate this betting, we're going to introduce a bit more code. First, we'll implement a `struct` that 
"""

# ╔═╡ 2e067625-6d77-46a2-8fd3-bcb030d4b957
begin
	mutable struct Better
		wallet::Wallet
		wins::Integer
		losses::Integer
	end

	Better(starting_amount) = Better(Wallet(starting_amount), 1, 1)
	
	Better(starting_amount, w, l) = Better(Wallet(starting_amount), w, l)
end

# ╔═╡ 621c6501-e37a-491b-8df1-fd4cdefcd16c
begin
	function bet_with_kelly!(better::Better; p=0.5)
		iv = better.wallet.value
		# determine how much we should bet
		L, W = better.losses, better.wins
		# for the first round, we're going to bet a random amount
		if L == W && W == 1
			bet_fraction = rand() * 0.5
		else
			bet_fraction = kelly_bet(p, L, W)
		end
		amount = ceil(better.wallet.value * bet_fraction)
		amount = Int(amount)
		println("Betting $bet_fraction, corresponding to $amount dollars.")
		change = bet_amount!(better.wallet, amount; p=p)
		# track the number of wins/losses
		if iv < better.wallet.value
			better.wins += 1
		else
			better.losses += 1
		end
		return better.wallet.value
	end
end

# ╔═╡ a94056e8-2cc2-422a-b83a-9b3c27af8b57
md"""Initial wins:
$(@bind initial_w Slider(1:100, default=1, show_value=true))

Initial losses:
$(@bind initial_l Slider(1:100, default=1, show_value=true))

The sliders affect the "attitude" the betters will have towards their position. The higher the wins relative to losses, the more riskier bets it will throw, as according to the contour plot. 
"""

# ╔═╡ cd05ad96-039b-4f64-b59a-91650981510e
better = Better(100, initial_w, initial_l);

# ╔═╡ 7617775e-f28b-47ab-bd45-15631ef1cdfb
bet_with_kelly!(better; p=winning_likelihood)

# ╔═╡ a8305d9b-b777-45d0-9189-5a4328afe344
begin
	"""Implement a function that runs a chain of \$n\$ trials
	"""
	function kelly_trial(; w=1, l=1, n=10, p=0.5)
		better = Better(start_amount, w, l)
		amounts = []
		for i in 1:n
			push!(amounts, bet_with_kelly!(better; p=p))
		end
		return amounts
	end
end

# ╔═╡ 24360308-cda4-43e4-ad90-3ed052cb0439
# spawn a thousand betters, each running their own chain
trajectories = [kelly_trial(; w=initial_w, l=initial_l) for i in 1:1000];

# ╔═╡ 34f2db28-8d98-43df-90da-75c338917bc4
plot(trajectories, legend=false, xlabel="Round", ylabel="Value / \$", color=:black, alpha=0.2)

# ╔═╡ 34cd0cbd-1d3b-4f24-8790-b76a9ed327b2
md"""This already looks a lot better than our all gas, no breaks policy from before: we don't earn _as much_, but at least we walk away with unempty wallets :wink:.
"""

# ╔═╡ 45b60a75-4438-4a92-8832-e74dc9bb4690
final_amounts_kelly = map(x -> x[end], trajectories);

# ╔═╡ 3319cbef-2dbf-4831-a4b1-5d004209bad4
kelly_hist = plot(histogram(final_amounts_kelly, bins=range(0,1_000; length=100)), xlabel="Final amount / \$", ylabel="Counts", legend=false, title="Amounts after $num_trials trials, with 10 games each")

# ╔═╡ 6a11c619-5ebb-42fb-83ac-99d25915ecb9
begin
	"""Calculate the expectation value of the trials, given a
	vector of final values for each trajectory.
	"""
	function expectation_value(results)
		h = fit(Histogram, results, 1:1_000)
		h = StatsBase.normalize(h, mode=:pdf)
		return sum(h.weights .* collect(1:999))
	end
end

# ╔═╡ 7bdf13a7-0a1a-4de9-bd00-ee94993f1a8b
expec = expectation_value(final_amounts_kelly);

# ╔═╡ 10a05035-8541-4bc0-a418-621145269b00
# number of instances where we made more money than we started with
winners = count(final_amounts_kelly .>= start_amount);

# ╔═╡ 256510d8-26a4-4ada-adfc-fc42cd5afafa
md"""An interesting thing that the WSJ article again omits is that the expected value after 10 rounds is \$$expec; while there is some variability to this, generally it does mean that you can expect to land right where you started, and in the trials I've run, generally a bit less than what you've started with.

Another way of looking at this is the number of times you chains that walk away with more money than they started with ($winners out of $num_trials). All of this is to say, even with known odds, you have a high likelihood of losing money in bets. Above all, _betting all of your money is never a good strategy._

## Letting RNG dictate your fate

After the experiments above, I thought about whether or not it would actually beat a purely stochastic betting policy: if we just bet random amounts of money each time, what could we expect?
"""

# ╔═╡ ec41bd6c-4427-4d36-b009-e1c70aea9583
begin
	"""Literally just bet random amounts of money as your "policy"
	"""
	function random_betting!(wallet; p=0.5)
		amount = Int(floor(rand() * wallet.value))
		bet_amount!(wallet, amount; p=p)
		return wallet.value
	end
end

# ╔═╡ 24f6853a-412e-478b-a041-31a8636a3b85
begin
	"""Implement a function that runs a chain of \$n\$ trials
	"""
	function random_trial(; n=10, p=0.5)
		wallet = Wallet(start_amount)
		amounts = []
		for i in 1:n
			push!(amounts, random_betting!(wallet; p=p))
		end
		return amounts
	end
end

# ╔═╡ 2fd52296-4ae3-472d-85ca-b04d214cfe81
random_trials = [random_trial() for i in 1:num_trials];

# ╔═╡ 0a1d5e58-0c26-4ef0-b923-e5b85274f1a2
plot(random_trials, legend=false, xlabel="Round", ylabel="Value / \$", color=:black, alpha=0.2)

# ╔═╡ 13795a93-b3a9-4987-8542-ced37f15a19c
md"""Seems like some chains actually manage to make a fair amount of money! What about the final states?
"""

# ╔═╡ 3ba898b6-a818-4f43-a18f-f7c1fcd46ee4
final_amounts_random = map(x -> x[end], random_trials);

# ╔═╡ e12e3c82-f929-4f0e-897d-871552101c4a
random_hist = plot(histogram(final_amounts_random, bins=range(0,1_000; length=100)), xlabel="Final amount / \$", ylabel="Counts", legend=false, title="Amounts after $num_trials trials, with 10 games each")

# ╔═╡ 7aa00f35-afa8-44eb-aab1-035746403eb2
expecrandom = expectation_value(final_amounts_random);

# ╔═╡ 8138817c-2a32-4efa-a110-f7ee8a70f5c1
randomwinners = count(final_amounts_random .>= start_amount) / num_trials;

# ╔═╡ 6701951a-e2a4-40ed-9036-a3fa5a34c4a3
md"""With the random betting as a baseline, it does seem that the Kelly strategy performs well, mostly by stopping you from losing all of your money.

## Conclusions

Basically, I've confirmed for myself that the Kelly strategy does improve upon the two simple baseline strategies (all gas no brakes, and random betting). The caveat however, is that even with the Kelly strategy your expectation would be to break even, and only about 50% of the time would you make more money than you started with.

In the next article, we'll look at using `Flux` to see if a reinforcement learning model can perform better.
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
ColorSchemes = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
ColorSchemes = "~3.13.0"
Distributions = "~0.25.11"
Plots = "~1.19.4"
PlutoUI = "~0.7.9"
StatsBase = "~0.33.9"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c3598e525718abcc440f69cc6d5f60dda0a1b61e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.6+5"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "e2f47f6d8337369411569fd45ae5753ca10394c6"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.0+6"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f53ca8d41e4753c41cdafa6ec5f7ce914b34be54"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "0.10.13"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random", "StaticArrays"]
git-tree-sha1 = "ed268efe58512df8c7e224d2e170afd76dd6a417"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.13.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "344f143fa0ec67e47917848795ab19c6a455f32c"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.32.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[DataAPI]]
git-tree-sha1 = "ee400abb2298bd13bfc3df1c412ed228061a2385"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.7.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4437b64df1e0adccc3e5d1adbc3ac741095e4677"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.9"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3889f646423ce91dd1055a76317e9a1d3a23fff1"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.11"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "92d8f9f208637e8d2d28c664051a00569c01493d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.1.5+1"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "LibVPX_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "3cc57ad0a213808473eafef4845a74766242e05f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.3.1+4"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8c8eac2af06ce35973c3eadb4ab3243076a408e7"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.1"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "35895cf184ceaab11fd778b4590144034a167a2f"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.1+14"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "cbd58c9deb1d304f5a245a0b7eb841a2560cfec6"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.1+5"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "dba1e8614e98949abfa60480b13653813d8f0157"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+0"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "9f473cdf6e2eb360c576f9822e7c765dd9d26dbc"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.58.0"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "eaf96e05a880f3db5ded5a5a8a7817ecba3c7392"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.58.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "7bf67e9a481712b3dbe9cb3dac852dc4b1162e02"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "44e3b40da000eab4ccb1aecdc4801c040026aeb5"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.13"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "81690084b6198a2e1da36fcfda16eeca9f9f24e4"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.1"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a4b12a1bd2ebade87891ab7e36fdbce582301a92"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.6"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[LibVPX_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "12ee7e23fa4d18361e7c2cde8f8337d4c3101bc7"
uuid = "dd192d2f-8180-539f-9fb4-cc70b1dcf69a"
version = "1.10.0+0"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "761a393aeccd6aa92ec3515e428c26bf99575b3b"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+0"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["DocStringExtensions", "LinearAlgebra"]
git-tree-sha1 = "7bd5f6565d80b6bf753738d2bc40a5dfea072070"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.2.5"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "6a8a2a625ab0dea913aba95c11370589e0239ff0"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.6"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "4ea90bd5d3985ae1f9a908bd4500ae88921c5ce7"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.0"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7937eda4681660b4d6aeeecc2f7e1c81c8ee4e2f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+0"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "4dd403333bcf0909341cfe57ec115152f937d7d8"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.1"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "94bf17e83a0e4b20c8d77f6af8ffe8cc3b386c0a"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "1.1.1"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "501c20a63a34ac1d015d5304da0e645f42d91c9f"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.11"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs"]
git-tree-sha1 = "1e72752052a3893d0f7103fbac728b60b934f5a5"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.19.4"

[[PlutoUI]]
deps = ["Base64", "Dates", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "Suppressor"]
git-tree-sha1 = "44e225d5837e2a2345e69a1d1e01ac2443ff9fcb"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.9"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "12fbe86da16df6679be7521dfb39fbc861e1dc7b"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.1"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RecipesBase]]
git-tree-sha1 = "b3fb709f3c97bfc6e948be68beeecb55a0b340ae"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "2a7a2469ed5d94a98dea0e85c46fa653d76be0cd"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.3.4"

[[Reexport]]
git-tree-sha1 = "5f6c21241f0f655da3952fd60aa18477cf96c220"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.1.0"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "LogExpFunctions", "OpenSpecFun_jll"]
git-tree-sha1 = "508822dca004bf62e210609148511ad03ce8f1d8"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "1.6.0"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "885838778bb6f0136f8317757d7803e0d81201e4"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.9"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "fed1ec1e65749c4d96fc20dd13bea72b55457e62"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.9"

[[StatsFuns]]
deps = ["LogExpFunctions", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "30cd8c360c54081f806b1ee14d2eecbef3c04c49"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.8"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "000e168f5cc9aded17b6999a560b7c11dda69095"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.0"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[Suppressor]]
git-tree-sha1 = "a819d77f31f83e5792a76081eee1ea6342ab8787"
uuid = "fd094767-a336-5f1f-9728-57cf17d0bbfb"
version = "0.2.0"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "d0c690d37c73aeb5ca063056283fde5585a41710"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll"]
git-tree-sha1 = "2839f1c1296940218e35df0bbb220f2a79686670"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.18.0+4"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "acc685bcf777b2202a904cdcb49ad34c2fa1880c"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.14.0+4"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7a5780a0d9c6864184b3a2eeeb833a0c871f00ab"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "0.1.6+4"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "c45f4e40e7aafe9d086379e5578947ec8b95a8fb"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+0"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d713c1ce4deac133e3334ee12f4adff07f81778f"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2020.7.14+2"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "487da2f8f2f0c8ee0e83f39d13037d6bbf0a45ab"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.0.0+3"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╠═885c1012-f0a2-11eb-0dcf-05079863473a
# ╟─4706db38-791f-44b2-849c-ebc758f64788
# ╟─571bf26e-5c81-46cc-a329-54bb3afe96bb
# ╠═04c4215a-46a7-47bf-bea1-880a98651c75
# ╟─fe87f0be-14c4-45e9-a60a-6bf1b7294930
# ╠═eb075aa1-176b-4a16-9443-5fa37a37c1b8
# ╟─2afc2ab8-aae6-4910-a5cc-29fd852a2ab3
# ╠═30088191-79c0-483c-b3c5-d44101393ad4
# ╟─212791cd-1e0b-429f-85cf-9ce462579f1a
# ╟─82c0d04e-f38f-4b8f-89cb-935b3887f8ab
# ╠═e60de62e-4307-41fe-934f-42fe1eeb6e07
# ╟─40db13aa-502d-429e-bb3c-120c42370923
# ╟─c5ef6a98-aa78-4219-81d2-fbd3c1e574e4
# ╠═41715d6a-ff67-4f7a-a13c-5a5c74a8c71b
# ╠═c0cdc755-6b8d-4bdb-8644-258028694d64
# ╠═decc4e31-b1b1-4b46-bb79-5630d6fe06f6
# ╟─f4bc3369-70ca-4959-bc44-f75094cb5f25
# ╠═b685cc54-d178-4753-9ab9-819f280e850f
# ╠═eacf9e94-966c-4042-91da-b4499e206e7b
# ╟─074cb90c-2ae2-44c1-87f5-6b316017ac2b
# ╟─5eda98de-f020-4cec-b75b-845ecf34a795
# ╠═8112fecc-9808-4989-ab1f-d3a6acee8a9e
# ╠═040225b7-dbd2-4378-af4d-b2154ef1dae6
# ╠═f049a6a6-1e87-411b-9c41-c2e03e0589a2
# ╠═b8eb2a1a-2d5b-4dab-a0b1-ecf51ab6a54e
# ╟─4646111a-9e92-4913-aadf-c31fda286007
# ╠═59110606-9d88-4fb1-829c-1efe1ef28035
# ╠═ccc48705-aee9-4dd9-9e04-e188a3475276
# ╠═df26cd51-7a1b-4893-804f-4a54237f95c6
# ╠═5ed2f2a7-fa82-40c0-bb6a-c70131c31142
# ╟─e3c4bfdc-f3d7-4523-ab22-d56efa3cc9df
# ╠═c42b146d-2b9f-4741-abe2-ce00b7b207cc
# ╠═336e2b2c-fd55-4076-a44b-08b448ce1224
# ╟─3ec8c8db-ad0f-4347-8994-cb6366bda92c
# ╠═de21be4a-aee3-4021-9a1d-55984bcd5b9e
# ╟─f7108217-d86d-42b0-9620-3a88e30eb1b0
# ╠═8ba32880-2378-4f3c-b67c-98c627d5e38f
# ╠═d038fdd0-34e6-4195-b3e2-d3cab1d8ed21
# ╠═4364aeda-ca17-47b7-90fc-9d6355405694
# ╟─60123607-3d57-4af9-a9e6-3fa2e69cd8be
# ╠═619c9c0c-00f7-45a3-abc9-5d03f23d4e34
# ╠═2e067625-6d77-46a2-8fd3-bcb030d4b957
# ╠═621c6501-e37a-491b-8df1-fd4cdefcd16c
# ╟─a94056e8-2cc2-422a-b83a-9b3c27af8b57
# ╠═cd05ad96-039b-4f64-b59a-91650981510e
# ╠═7617775e-f28b-47ab-bd45-15631ef1cdfb
# ╠═a8305d9b-b777-45d0-9189-5a4328afe344
# ╠═24360308-cda4-43e4-ad90-3ed052cb0439
# ╠═34f2db28-8d98-43df-90da-75c338917bc4
# ╠═34cd0cbd-1d3b-4f24-8790-b76a9ed327b2
# ╠═45b60a75-4438-4a92-8832-e74dc9bb4690
# ╠═3319cbef-2dbf-4831-a4b1-5d004209bad4
# ╠═6a11c619-5ebb-42fb-83ac-99d25915ecb9
# ╠═7bdf13a7-0a1a-4de9-bd00-ee94993f1a8b
# ╠═10a05035-8541-4bc0-a418-621145269b00
# ╠═256510d8-26a4-4ada-adfc-fc42cd5afafa
# ╠═ec41bd6c-4427-4d36-b009-e1c70aea9583
# ╠═24f6853a-412e-478b-a041-31a8636a3b85
# ╠═2fd52296-4ae3-472d-85ca-b04d214cfe81
# ╠═0a1d5e58-0c26-4ef0-b923-e5b85274f1a2
# ╟─13795a93-b3a9-4987-8542-ced37f15a19c
# ╠═3ba898b6-a818-4f43-a18f-f7c1fcd46ee4
# ╠═e12e3c82-f929-4f0e-897d-871552101c4a
# ╠═7aa00f35-afa8-44eb-aab1-035746403eb2
# ╠═8138817c-2a32-4efa-a110-f7ee8a70f5c1
# ╟─6701951a-e2a4-40ed-9036-a3fa5a34c4a3
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
