<script lang="ts">
	let { href = '/owner', label = 'Owner of restaurant ?' }: { href?: string; label?: string } = $props();
</script>

<a class="owner" {href} aria-label={label}>
	<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		<path d="m2 7 4.41-4.41A2 2 0 0 1 7.83 2h8.34a2 2 0 0 1 1.42.59L22 7" />
		<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8" />
		<path d="M15 22v-4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v4" />
		<path d="M2 7h20" />
		<path d="M22 7v3a2 2 0 0 1-2 2a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 16 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 12 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 8 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 4 12a2 2 0 0 1-2-2V7" />
	</svg>
	<span class="label">{label}</span>
</a>

<style>
	.owner {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		height: 46px;
		padding: 0 22px 0 18px;
		border-radius: 999px;
		background: #2f5d3a;
		color: #fff;
		font:
			600 16px/1 system-ui,
			-apple-system,
			'Segoe UI',
			sans-serif;
		text-decoration: none;
		white-space: nowrap;
		box-shadow: 0 2px 12px rgb(0 0 0 / 18%);
		transition: background 0.15s;
	}

	.owner:hover {
		background: #264d30;
	}

	.owner:focus-visible {
		outline: 2px solid #2563eb;
		outline-offset: 2px;
	}

	svg {
		flex: none;
		width: 22px;
		height: 22px;
	}

	@media (max-width: 900px) {
		.owner {
			width: 46px;
			padding: 0;
			justify-content: center;
		}

		.label {
			display: none;
		}
	}
</style>