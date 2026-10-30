<script>
	import { onMount } from 'svelte';
	import { fly } from 'svelte/transition';
	import RestaurantCard from '#lib/components/RestaurantCard.svelte';
	import RestaurantDetails from '#lib/components/RestaurantDetails.svelte';

	let { data } = $props();
	let selectedRestaurant = $state(/** @type {typeof data.restaurants[number] | null} */ (null));
	let selectedCuisine = $state(/** @type {string | null} */ (null));
	let sidebarOpen = $state(true);
	let searchArea = $state(
		/** @type {{ lat: number; lng: number; radius: number } | null} */ (null)
	);

	/**
	 * @param {number} lat1
	 * @param {number} lng1
	 * @param {number} lat2
	 * @param {number} lng2
	 */
	function distanceInMeters(lat1, lng1, lat2, lng2) {
		/** @param {number} degrees */
		const toRadians = (degrees) => (degrees * Math.PI) / 180;
		const earthRadius = 6_371_000;
		const latitudeDelta = toRadians(lat2 - lat1);
		const longitudeDelta = toRadians(lng2 - lng1);
		const haversine =
			Math.sin(latitudeDelta / 2) ** 2 +
			Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(longitudeDelta / 2) ** 2;

		return earthRadius * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
	}

	onMount(() => {
		/** @param {Event} event */
		const handleMapSearch = (event) => {
			if (!(event instanceof CustomEvent)) return;
			const { lat, lng, radius } = event.detail ?? {};
			if (
				typeof lat !== 'number' ||
				!Number.isFinite(lat) ||
				typeof lng !== 'number' ||
				!Number.isFinite(lng) ||
				typeof radius !== 'number' ||
				!Number.isFinite(radius) ||
				radius <= 0
			) {
				return;
			}

			searchArea = { lat, lng, radius };
		};

		/** @param {Event} event */
		const handleMapRadius = (event) => {
			if (!(event instanceof CustomEvent) || typeof event.detail !== 'number') return;
			if (!Number.isFinite(event.detail) || event.detail <= 0 || !searchArea) return;
			searchArea = { ...searchArea, radius: event.detail };
		};

		const handleMapReset = () => {
			searchArea = null;
		};

		window.addEventListener('map-search', handleMapSearch);
		window.addEventListener('map-radius', handleMapRadius);
		window.addEventListener('map-reset', handleMapReset);

		return () => {
			window.removeEventListener('map-search', handleMapSearch);
			window.removeEventListener('map-radius', handleMapRadius);
			window.removeEventListener('map-reset', handleMapReset);
		};
	});

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
		data.restaurants.filter((restaurant) => {
			const isWithinSearchArea =
				searchArea === null ||
				(restaurant.latitude !== null &&
					restaurant.longitude !== null &&
					distanceInMeters(
						searchArea.lat,
						searchArea.lng,
						restaurant.latitude,
						restaurant.longitude
					) <= searchArea.radius);
			const matchesCuisine =
				selectedCuisine === null ||
				restaurant.tags.some((tag) => tag.kind === 'cuisine' && tag.slug === selectedCuisine);

			return isWithinSearchArea && matchesCuisine;
		})
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
{:else if sidebarOpen}
	<aside class="sidebar" transition:fly={{ x: -32, duration: 260 }}>
		<div class="head">
			<div class="brand-row">
				<span class="brand">Tastemap.</span>
				<button
					type="button"
					class="close"
					aria-label="Fermer la liste des restaurants"
					onclick={() => (sidebarOpen = false)}>✕</button
				>
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
				<p class="empty">Aucun restaurant dans cette zone avec ces filtres.</p>
			{/each}
		</div>

		<p class="footer">Tap any table to inspect notes, dishes &amp; coordinates.</p>
	</aside>
{:else}
	<button
		type="button"
		class="open-sidebar"
		aria-label="Ouvrir la liste des restaurants"
		onclick={() => (sidebarOpen = true)}
		transition:fly={{ x: -24, duration: 220 }}
	>
		<svg
			viewBox="0 0 24 24"
			fill="none"
			stroke="currentColor"
			stroke-width="1.8"
			stroke-linecap="round"
			stroke-linejoin="round"
			aria-hidden="true"
		>
			<rect x="3" y="4" width="18" height="16" rx="2" />
			<path d="M9 4v16" />
			<path d="M13 9h4M13 13h4M13 17h3" />
		</svg>
		<span>Restaurants</span>
	</button>
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

	.open-sidebar {
		position: fixed;
		top: 16px;
		left: 16px;
		z-index: 1100;
		display: inline-flex;
		align-items: center;
		gap: 10px;
		height: 46px;
		padding: 0 18px;
		border: 1px solid #e6e1d8;
		border-radius: 999px;
		background: #fff;
		color: #1d1b18;
		box-shadow: 0 2px 12px rgb(0 0 0 / 18%);
		font:
			600 16px/1 system-ui,
			-apple-system,
			'Segoe UI',
			sans-serif;
		cursor: pointer;
		transition:
			background 0.15s,
			box-shadow 0.15s,
			transform 0.15s;
	}

	.open-sidebar:hover {
		background: #faf8f4;
		box-shadow: 0 4px 16px rgb(0 0 0 / 22%);
		transform: translateY(-1px);
	}

	.open-sidebar:focus-visible {
		outline: 2px solid #2563eb;
		outline-offset: 2px;
	}

	.open-sidebar svg {
		width: 20px;
		height: 20px;
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
