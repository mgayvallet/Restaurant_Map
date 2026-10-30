<script lang="ts">
	import { onMount, mount, unmount, type Snippet } from 'svelte';
	import favicon from '#lib/assets/favicon.svg';
	import SearchBar from '#lib/components/Searchbar.svelte';
	import OwnerButton from '#lib/components/Ownerbutton.svelte';
	import MapPin from '#lib/components/MapPin.svelte';
	import '../app.css';
	import 'leaflet/dist/leaflet.css';

	type SearchArea = {
		remove(): void;
		getLatLng(): { lat: number; lng: number };
		setRadius(radius: number): void;
	};

	let {
		data,
		children
	}: {
		data: import('./$types').LayoutServerData;
		children: Snippet;
	} = $props();
	let mapElement: HTMLDivElement;

	const INITIAL_VIEW: [number, number] = [51.505, -0.09];
	const INITIAL_ZOOM = 13;

	onMount(() => {
		let disposed = false;
		let cleanup: (() => void) | undefined;

		import('leaflet').then((L) => {
			if (disposed) return;

			const map = L.map(mapElement, { zoomControl: false }).setView(INITIAL_VIEW, INITIAL_ZOOM);
			let searchArea: SearchArea | undefined;
			let searchCenter: ReturnType<typeof L.circleMarker> | undefined;

			const fitArea = (lat: number, lng: number, radius: number) =>
				map.flyToBounds(L.latLng(lat, lng).toBounds(radius * 2), { padding: [40, 40] });

			const handleZoom = (event: Event) => {
				if (!(event instanceof CustomEvent)) return;
				if (event.detail === 'in') map.zoomIn();
				if (event.detail === 'out') map.zoomOut();
			};

			const handleSearch = (event: Event) => {
				if (!(event instanceof CustomEvent)) return;
				const { lat, lng, radius } = event.detail as { lat: number; lng: number; radius: number };
				searchArea?.remove();
				searchCenter?.remove();
				searchArea = L.circle([lat, lng], {
					radius,
					color: '#2f5d3a',
					weight: 1.5,
					fillOpacity: 0.08
				}).addTo(map);
				searchCenter = L.circleMarker([lat, lng], {
					radius: 8,
					color: '#fff',
					weight: 3,
					fillColor: '#2f5d3a',
					fillOpacity: 1
				}).addTo(map);
				fitArea(lat, lng, radius);
			};

			const handleRadius = (event: Event) => {
				if (!(event instanceof CustomEvent) || !searchArea) return;
				const radius = event.detail as number;
				const { lat, lng } = searchArea.getLatLng();
				searchArea.setRadius(radius);
				fitArea(lat, lng, radius);
			};

			const handleReset = () => {
				searchArea?.remove();
				searchArea = undefined;
				searchCenter?.remove();
				searchCenter = undefined;
				map.flyTo(INITIAL_VIEW, INITIAL_ZOOM);
			};

			const handleCuisineFilter = (event: Event) => {
				if (!(event instanceof CustomEvent)) return;
				const cuisineSlug = event.detail;
				if (cuisineSlug !== null && typeof cuisineSlug !== 'string') return;

				for (const { restaurant, marker } of pins) {
					const matches =
						cuisineSlug === null ||
						restaurant.tags.some((tag) => tag.kind === 'cuisine' && tag.slug === cuisineSlug);
					if (matches && !map.hasLayer(marker)) marker.addTo(map);
					if (!matches && map.hasLayer(marker)) marker.remove();
				}
			};

			window.addEventListener('map-zoom', handleZoom);
			window.addEventListener('map-search', handleSearch);
			window.addEventListener('map-radius', handleRadius);
			window.addEventListener('map-reset', handleReset);
			window.addEventListener('map-filter-cuisine', handleCuisineFilter);

			L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
				attribution:
					'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
			}).addTo(map);

			const pins = data.restaurants.flatMap((restaurant, index) => {
				if (restaurant.latitude === null || restaurant.longitude === null) return [];

				const pinElement = document.createElement('div');
				const pin = mount(MapPin, {
					target: pinElement,
					props: { rank: restaurant.rank ?? index + 1 }
				});
				const marker = L.marker([restaurant.latitude, restaurant.longitude], {
					icon: L.divIcon({
						html: pinElement,
						className: '',
						iconSize: [48, 48],
						iconAnchor: [0, 24]
					})
				})
					.addTo(map)
					.bindPopup(restaurant.name);

				return [{ restaurant, pin, marker }];
			});

			cleanup = () => {
				window.removeEventListener('map-zoom', handleZoom);
				window.removeEventListener('map-search', handleSearch);
				window.removeEventListener('map-radius', handleRadius);
				window.removeEventListener('map-reset', handleReset);
				window.removeEventListener('map-filter-cuisine', handleCuisineFilter);
				for (const { pin } of pins) unmount(pin);
				map.remove();
			};
		});

		return () => {
			disposed = true;
			cleanup?.();
		};
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<div bind:this={mapElement} class="map" aria-label="Carte interactive"></div>

<header class="topbar">
	<div class="topbar-search">
		<SearchBar />
	</div>
	<div class="topbar-owner">
		<OwnerButton href="/owner" />
	</div>
</header>

{@render children()}

<div class="zoom-control" aria-label="Contrôles de zoom">
	<button
		type="button"
		aria-label="Zoom avant"
		onclick={() => window.dispatchEvent(new CustomEvent('map-zoom', { detail: 'in' }))}>+</button
	>
	<button
		type="button"
		aria-label="Zoom arrière"
		onclick={() => window.dispatchEvent(new CustomEvent('map-zoom', { detail: 'out' }))}>−</button
	>
</div>

<style>
	.map {
		position: fixed;
		inset: 0;
	}

	.topbar {
		position: fixed;
		top: 16px;
		left: 16px;
		right: 16px;
		z-index: 1000;
		display: grid;
		grid-template-columns: 1fr minmax(0, 620px) 1fr;
		align-items: start;
		gap: 12px;
		pointer-events: none;
	}

	.topbar-search {
		grid-column: 2;
		pointer-events: auto;
	}

	.topbar-owner {
		grid-column: 3;
		justify-self: end;
		pointer-events: auto;
	}

	@media (max-width: 900px) {
		.topbar {
			grid-template-columns: minmax(0, 1fr) auto;
		}

		.topbar-search {
			grid-column: 1;
		}

		.topbar-owner {
			grid-column: 2;
		}
	}

	.zoom-control {
		position: fixed;
		right: 10px;
		bottom: 10px;
		z-index: 1000;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		border: 2px solid rgb(0 0 0 / 20%);
		border-radius: 4px;
	}

	.zoom-control button {
		display: block;
		width: 30px;
		height: 30px;
		border: 0;
		background: #fff;
		color: #000;
		cursor: pointer;
		font:
			bold 22px/30px Arial,
			sans-serif;
		text-align: center;
	}

	.zoom-control button + button {
		border-top: 1px solid #ccc;
	}

	.zoom-control button:hover {
		background: #f4f4f4;
	}

	.zoom-control button:focus-visible {
		position: relative;
		z-index: 1;
		outline: 2px solid #2563eb;
		outline-offset: -2px;
	}
</style>	