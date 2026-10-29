<script>
	let {
		slug,
		name,
		photos,
		tags,
		priceTier,
		ratingAvg,
		ratingCount,
		description,
		tagline,
		streetAddress,
		city,
		postcode,
		neighborhood,
		phone,
		onBack
	} = $props();

	const mapsUrl = $derived(
		`https://maps.google.com/?q=${encodeURIComponent(
			`${streetAddress}, ${city} ${postcode ?? ''}`
		)}`
	);
</script>

<aside class="detail">
	<button type="button" class="back" onclick={onBack}>← Back to all places</button>

	<div class="content">
		<div class="gallery">
			{#each photos.slice(0, 3) as photo, index (`${slug}-${photo.position}`)}
				{@const fallbackImage = `https://picsum.photos/seed/${encodeURIComponent(
					`${slug}-${photo.position}`
				)}/600/360`}
				<figure class:main={index === 0}>
					<img
						src={photo.url}
						alt={photo.alt_text ?? name}
						onerror={(event) => {
							if (event.currentTarget instanceof HTMLImageElement && event.currentTarget.src !== fallbackImage) {
								event.currentTarget.src = fallbackImage;
							}
						}}
					/>
					{#if photo.caption}<figcaption>{photo.caption}</figcaption>{/if}
				</figure>
			{/each}
		</div>

		<h1>{name}</h1>

		<div class="meta">
			{#each tags as tag (`${slug}-${tag.slug}`)}
				<span class="tag">{tag.name}</span>
			{/each}
			<span class="sep">·</span>
			<span class="price">{'€'.repeat(priceTier)}</span>
			<span class="rating">
				<strong>{ratingAvg.toFixed(1)}</strong>
				<small>({ratingCount} reviews)</small>
			</span>
		</div>

		<p class="description">{description ?? tagline ?? ''}</p>

		<div class="address">
			<span class="icon">⌖</span>
			<div>
				<p>
					{streetAddress}{#if postcode}, {postcode}{/if},
					{city} · {neighborhood}
				</p>
				<a href={mapsUrl} target="_blank" rel="noreferrer">Get Directions ↗</a>
			</div>
		</div>
	</div>

	<div class="footer">
		{#if phone}
			<a class="book" href={`tel:${phone}`}>🍴 Book a Table</a>
		{/if}
	</div>
</aside>

<style>
	.detail {
		position: fixed;
		top: 0;
		bottom: 0;
		left: 0;
		z-index: 1101;
		display: flex;
		flex-direction: column;
		width: 380px;
		border-right: 1px solid #e6e1d8;
		background: #faf8f4;
		color: #1d1b18;
		font-family: system-ui, sans-serif;
	}

	.back {
		padding: 18px 22px;
		border: 0;
		border-bottom: 1px solid #e6e1d8;
		background: none;
		font: inherit;
		font-size: 15px;
		font-weight: 600;
		text-align: left;
		cursor: pointer;
	}

	.content {
		flex: 1;
		padding: 22px;
		overflow-y: auto;
	}

	.gallery {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 5px;
	}

	figure {
		position: relative;
		margin: 0;
	}

	figure.main {
		grid-column: span 2;
	}

	figure img {
		display: block;
		width: 100%;
		height: 95px;
		object-fit: cover;
	}

	figure.main img {
		height: 200px;
	}

	figcaption {
		position: absolute;
		bottom: 8px;
		left: 8px;
		padding: 3px 8px;
		border-radius: 999px;
		background: rgb(0 0 0 / 55%);
		color: #fff;
		font-size: 11px;
	}

	h1 {
		margin: 24px 0 14px;
		font-family: Georgia, serif;
		font-size: 30px;
	}

	.meta {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
	}

	.tag {
		padding: 2px 9px;
		border: 1px solid #d9d3c9;
		border-radius: 999px;
		color: #5d5850;
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.08em;
		text-transform: uppercase;
	}

	.sep {
		color: #a6a198;
	}

	.price {
		font-weight: 700;
	}

	.rating {
		margin-left: auto;
		color: #b5631e;
	}

	.rating strong {
		color: #1d1b18;
	}

	.rating small {
		color: #8a857c;
	}

	.description {
		margin: 16px 0 0;
		padding-bottom: 22px;
		border-bottom: 1px solid #e6e1d8;
		color: #5d5850;
		font-size: 15px;
		line-height: 1.7;
	}

	.address {
		display: flex;
		gap: 8px;
		margin-top: 22px;
		font-size: 14px;
	}

	.address p {
		margin: 0;
		font-weight: 500;
	}

	.address a {
		color: #2f5d3a;
		font-weight: 600;
		text-decoration: none;
	}

	.icon {
		color: #8a857c;
	}

	.footer {
		padding: 18px 22px;
		border-top: 1px solid #e6e1d8;
	}

	.book {
		display: block;
		width: 100%;
		padding: 12px;
		border: 0;
		border-radius: 999px;
		background: #2f5d3a;
		color: #fff;
		font: inherit;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		text-align: center;
		text-decoration: none;
	}

	.book:hover {
		background: #264c30;
	}
</style>