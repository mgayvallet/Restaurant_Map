<script>
	let { rank, active = false } = $props();
</script>

<div class="pin" class:active>
	<div class="drop">
		<span class="number">{rank}</span>
	</div>
</div>

<style>
	.pin {
		display: grid;
		place-items: center;
		width: 48px;
		height: 48px;
		cursor: pointer;
	}

	.drop {
		display: grid;
		place-items: center;
		width: 34px;
		height: 34px;
		border: 2.5px solid #fff;
		border-radius: 50% 50% 50% 0;
		background: #2f5d3a;
		box-shadow: 0 3px 8px rgb(0 0 0 / 30%);
		transform: rotate(45deg);
		transition: transform 0.15s ease;
	}

	.number {
		color: #fff;
		font-family: Georgia, serif;
		font-size: 17px;
		font-weight: 700;
		transform: rotate(-45deg);
	}

	.pin:hover .drop {
		transform: rotate(45deg) scale(1.08);
	}

	.pin.active .drop {
		width: 40px;
		height: 40px;
		box-shadow:
			0 0 0 8px rgb(236 200 154 / 45%),
			0 3px 10px rgb(0 0 0 / 30%);
	}
</style>