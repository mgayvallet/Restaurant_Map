<script lang="ts">
	const RADII = [1, 2, 5] as const;

	let query = $state('');
	let radiusIndex = $state(0);
	let loading = $state(false);
	let error = $state('');

	const radius = $derived(RADII[radiusIndex]);

	async function search(event: SubmitEvent) {
		event.preventDefault();
		const q = query.trim();
		if (!q || loading) return;

		loading = true;
		error = '';
		try {
			const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(q)}`;
			const res = await fetch(url, { headers: { 'Accept-Language': 'fr' } });
			if (!res.ok) throw new Error(`HTTP ${res.status}`);

			const [place] = (await res.json()) as { lat: string; lon: string }[];
			if (!place) {
				error = 'Adresse introuvable';
				return;
			}

			window.dispatchEvent(
				new CustomEvent('map-search', {
					detail: { lat: Number(place.lat), lng: Number(place.lon), radius: radius * 1000 }
				})
			);
		} catch {
			error = 'Recherche indisponible';
		} finally {
			loading = false;
		}
	}

	function cycleRadius() {
		radiusIndex = (radiusIndex + 1) % RADII.length;
		window.dispatchEvent(new CustomEvent('map-radius', { detail: radius * 1000 }));
	}

	function reset() {
		query = '';
		error = '';
		window.dispatchEvent(new CustomEvent('map-reset'));
	}
</script>

<div class="search-wrap">
	<form class="search" role="search" onsubmit={search} aria-busy={loading}>
		<svg class="icon" class:loading viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
			<circle cx="11" cy="11" r="7" />
			<path d="m20 20-3.5-3.5" />
		</svg>

		<input
			type="text"
			bind:value={query}
			placeholder="Search an address…"
			aria-label="Rechercher une adresse"
			autocomplete="off"
			enterkeyhint="search"
		/>

		<button
			type="button"
			class="radius"
			onclick={cycleRadius}
			aria-label={`Rayon de ${radius} km, cliquer pour changer`}
		>
			<span>{radius}km</span>
			<span>radius</span>
		</button>

		<button type="button" class="reset" onclick={reset} aria-label="Réinitialiser la recherche">
			<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
				<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
				<path d="M3 3v5h5" />
			</svg>
		</button>
	</form>

	{#if error}
		<p class="error" role="status">{error}</p>
	{/if}
</div>

<style>
	.search-wrap {
		position: relative;
	}

	.search {
		display: flex;
		align-items: center;
		gap: 8px;
		height: 46px;
		padding: 0 7px 0 16px;
		background: #fff;
		border-radius: 999px;
		box-shadow:
			0 2px 12px rgb(0 0 0 / 12%),
			0 0 0 1px rgb(0 0 0 / 4%);
		transition: box-shadow 0.15s;
	}

	.search:focus-within {
		box-shadow:
			0 2px 12px rgb(0 0 0 / 12%),
			0 0 0 2px #2f5d3a;
	}

	.icon {
		flex: none;
		width: 20px;
		height: 20px;
		color: #6b6b6b;
	}

	.icon.loading {
		animation: pulse 0.8s ease-in-out infinite alternate;
	}

	@keyframes pulse {
		to {
			opacity: 0.3;
		}
	}

	input {
		flex: 1;
		min-width: 0;
		border: 0;
		outline: 0;
		background: transparent;
		color: #222;
		font:
			16px/1.2 system-ui,
			-apple-system,
			'Segoe UI',
			sans-serif;
	}

	input::placeholder {
		color: #8a8a8a;
	}

	.radius {
		flex: none;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 32px;
		padding: 0 12px;
		border: 0;
		border-radius: 999px;
		background: #f0f0ee;
		color: #333;
		font:
			600 10px/1.1 system-ui,
			-apple-system,
			sans-serif;
		cursor: pointer;
	}

	.radius:hover {
		background: #e5e5e2;
	}

	.reset {
		flex: none;
		display: grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border: 0;
		border-radius: 50%;
		background: transparent;
		color: #555;
		cursor: pointer;
	}

	.reset:hover {
		background: #f0f0ee;
	}

	.reset svg {
		width: 18px;
		height: 18px;
	}

	button:focus-visible {
		outline: 2px solid #2563eb;
		outline-offset: 2px;
	}

	.error {
		position: absolute;
		top: calc(100% + 6px);
		left: 16px;
		margin: 0;
		padding: 4px 10px;
		border-radius: 6px;
		background: #fff;
		color: #b42318;
		font: 13px/1.4 system-ui, sans-serif;
		box-shadow: 0 2px 8px rgb(0 0 0 / 12%);
	}
</style>