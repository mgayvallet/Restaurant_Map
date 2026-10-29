<script>
	/**
	 * @typedef {{
	 *   rank: number;
	 *   name: string;
	 *   description?: string;
	 *   price?: number;
	 *   image?: string;
	 *   fallbackImage: string;
	 *   topPick?: boolean;
	 *   onSelect: () => void;
	 * }} RestaurantCardProps
	 */

	/** @type {RestaurantCardProps} */
	let {
		rank,
		name,
		description = '',
		price = 2,
		image,
		fallbackImage,
		topPick = false,
		onSelect = () => {}
	} = $props();
</script>

<button type="button" class="card" class:top={topPick} onclick={() => onSelect()}>
	<span class="rank">{rank}</span>
	<img
		class="thumb"
		src={image ?? fallbackImage}
		alt={name}
		onerror={(event) => {
			if (event.currentTarget instanceof HTMLImageElement && event.currentTarget.src !== fallbackImage) {
				event.currentTarget.src = fallbackImage;
			}
		}}
	/>
	<div class="info">
		<span class="name">{name}</span>
		{#if description}<span class="description">{description}</span>{/if}
	</div>
	<div class="side">
		<span class="price">
			{#each [1, 2, 3, 4] as level}
				<span class:off={level > price}>€</span>
			{/each}
		</span>
		{#if topPick}<span class="top-pick">Top pick</span>{/if}
	</div>
</button>

<style>
	.card {
		display: grid;
		grid-template-columns: 28px 48px minmax(0, 1fr) auto;
		align-items: center;
		gap: 14px;
		width: 100%;
		min-width: 0;
		padding: 14px 16px 14px 12px;
		border: 1px solid transparent;
		border-radius: 999px;
		background: transparent;
		color: inherit;
		font: inherit;
		text-align: left;
		cursor: pointer;
	}
	.card:hover {
		background: #f3efe8;
	}
	.card.top {
		border-color: #ecc89a;
		background: #fcebd6;
	}
	.rank {
		font-family: Georgia, serif;
		font-size: 24px;
		font-weight: 600;
		text-align: center;
	}
	.thumb {
		width: 48px;
		height: 48px;
		border-radius: 6px;
		object-fit: cover;
	}
	.info {
		display: flex;
		min-width: 0;
		flex-direction: column;
		gap: 2px;
	}
	.name {
		overflow: hidden;
		font-size: 17px;
		font-weight: 600;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.description {
		overflow: hidden;
		color: #5d5850;
		font-size: 14px;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.side {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 4px;
	}
	.price {
		font-weight: 600;
	}
	.off {
		color: #cfc9bf;
	}
	.top-pick {
		color: #b5631e;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
	}
</style>
