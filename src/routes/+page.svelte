<script>
	import RestaurantCard from '#lib/components/RestaurantCard.svelte';
	import RestaurantDetails from '#lib/components/RestaurantDetails.svelte';

	let { data } = $props();
	let selectedRestaurant = $state(/** @type {typeof data.restaurants[number] | null} */ (null));
	let selectedCuisine = $state(/** @type {string | null} */ (null));

	const cuisines = $derived.by(() => {
		const cuisineMap = new Map();
		for (const restaurant of data.restaurants) {
			for (const tag of restaurant.tags) {
				if (tag.kind === 'cuisine') cuisineMap.set(tag.slug, { slug: tag.slug, name: tag.name });
			}
		}
		return [...cuisineMap.values()];
	});

	const filteredRestaurants = $derived(
		selectedCuisine === null
			? data.restaurants
			: data.restaurants.filter((restaurant) =>
					restaurant.tags.some(
						(tag) => tag.kind === 'cuisine' && tag.slug === selectedCuisine
					)
				)
	);

	/** @param {string | null} slug */
	function filterByCuisine(slug) {
		selectedCuisine = slug;
		window.dispatchEvent(new CustomEvent('map-filter-cuisine', { detail: slug }));
	}
</script>

{#if selectedRestaurant}
	<RestaurantDetails
		slug={selectedRestaurant.slug}
		name={selectedRestaurant.name}
		photos={selectedRestaurant.photos}
		tags={selectedRestaurant.tags}
		priceTier={selectedRestaurant.price_tier}
		ratingAvg={selectedRestaurant.rating_avg}
		ratingCount={selectedRestaurant.rating_count}
		description={selectedRestaurant.description}
		tagline={selectedRestaurant.tagline}
		streetAddress={selectedRestaurant.street_address}
		city={selectedRestaurant.city}
		postcode={selectedRestaurant.postcode}
		neighborhood={selectedRestaurant.neighborhood}
		phone={selectedRestaurant.phone}
		onBack={() => (selectedRestaurant = null)}
	/>
{:else}
<aside class="sidebar">
	<div class="head">
		<div class="brand-row">
			<span class="brand">Tastemap.</span>
			<button type="button" class="close" aria-label="Fermer">✕</button>
		</div>

		<span class="location">
			<span class="dot"></span>London · 1km radius · {filteredRestaurants.length} places
		</span>

		<h1>Your top tables</h1>
		<p class="lede">
			Ranked head-to-head, so your #3 really is better than your #4 — no five-star mush.
		</p>

		<div class="tabs">
			<button type="button" class="active">
				Ranked <span class="count">{data.restaurantCounts.ranked}</span>
			</button>
			<button type="button">
				Want to try <span class="count">{data.restaurantCounts.wantToTry}</span>
			</button>
		</div>
	</div>

	<div class="filters">
		<button
			type="button"
			class="chip"
			class:active={selectedCuisine === null}
			aria-pressed={selectedCuisine === null}
			onclick={() => filterByCuisine(null)}>All</button
		>
		{#each cuisines as cuisine (cuisine.slug)}
			<button
				type="button"
				class="chip"
				class:active={selectedCuisine === cuisine.slug}
				aria-pressed={selectedCuisine === cuisine.slug}
				onclick={() => filterByCuisine(cuisine.slug)}>{cuisine.name}</button
			>
		{/each}
	</div>

	<div class="list">
		{#each filteredRestaurants as restaurant, index (restaurant.id)}
			<RestaurantCard
				rank={restaurant.rank ?? index + 1}
				name={restaurant.name}
				description={`${restaurant.tagline ?? restaurant.description ?? ''} · ${restaurant.neighborhood}`}
				price={restaurant.price_tier}
				image={restaurant.photos[0]?.url}
				fallbackImage={`https://picsum.photos/seed/${encodeURIComponent(restaurant.slug)}/120`}
				topPick={restaurant.rank === 1}
				onSelect={() => (selectedRestaurant = restaurant)}
			/>
		{:else}
			<p class="empty">Aucun restaurant pour cette cuisine.</p>
		{/each}
	</div> 

	<p class="footer">Tap any table to inspect notes, dishes &amp; coordinates.</p>
</aside>
{/if}

<style>
	.sidebar {
		position: fixed;
		top: 0;
		bottom: 0;
		left: 0;
		z-index: 1100;
		display: flex;
		flex-direction: column;
		width: min(380px, 100vw);
		height: 100dvh;
		box-sizing: border-box;
		border-right: 1px solid #e6e1d8;
		background: #faf8f4;
		color: #1d1b18;
		font-family: system-ui, sans-serif;
	}

	.head {
		padding: 20px 22px 0;
	}

	.brand-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.brand,
	h1 {
		font-family: Georgia, serif;
		font-weight: 700;
	}

	.brand {
		font-size: 22px;
	}

	.close {
		border: 0;
		background: none;
		color: #6b665d;
		font-size: 18px;
		cursor: pointer;
	}

	.location {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		margin-top: 18px;
		padding: 4px 12px;
		border: 1px solid #e6e1d8;
		border-radius: 999px;
		background: #f3f0ea;
		font-size: 13px;
	}

	.dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background: #2f5d3a;
	}

	h1 {
		margin: 20px 0 10px;
		font-size: 30px;
	}

	.lede {
		margin: 0;
		color: #5d5850;
		font-size: 14px;
		line-height: 1.6;
	}

	.tabs {
		display: flex;
		gap: 26px;
		margin-top: 20px;
		border-bottom: 1px solid #e6e1d8;
	}

	.tabs button {
		margin-bottom: -1px;
		padding: 0 0 10px;
		border: 0;
		border-bottom: 2px solid transparent;
		background: none;
		color: #8a857c;
		font: inherit;
		font-size: 16px;
		cursor: pointer;
	}

	.tabs button.active {
		border-bottom-color: #2f5d3a;
		color: #1d1b18;
	}

	.count {
		color: #a6a198;
		font-size: 12px;
	}

	.filters {
		display: flex;
		gap: 8px;
		padding: 14px 22px;
		overflow-x: auto;
		border-bottom: 1px solid #e6e1d8;
	}

	.chip {
		flex: none;
		padding: 4px 13px;
		border: 1px solid #e6e1d8;
		border-radius: 999px;
		background: #f3f0ea;
		font: inherit;
		font-size: 13px;
		cursor: pointer;
	}

	.chip.active {
		border-color: #2f5d3a;
		background: #2f5d3a;
		color: #fff;
	}

	.list {
		flex: 1;
		min-height: 0;
		padding: 10px;
		overflow-y: auto;
	}

	.empty {
		padding: 18px;
		color: #8a857c;
		font-size: 14px;
		text-align: center;
	}

	.footer {
		margin: 0;
		padding: 14px 22px;
		border-top: 1px solid #e6e1d8;
		color: #8a857c;
		font-size: 13px;
		text-align: center;
	}

	@media (max-height: 600px) {
		.head {
			padding: 12px 16px 0;
		}

		.location {
			margin-top: 8px;
		}

		h1 {
			margin: 10px 0 6px;
			font-size: 25px;
		}

		.lede {
			display: none;
		}

		.tabs {
			margin-top: 10px;
		}

		.filters {
			padding: 8px 16px;
		}

		.footer {
			padding: 8px 12px;
		}
	}
</style>
