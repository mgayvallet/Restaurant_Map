import { getRestaurantCounts, getRestaurants } from '#lib/server/database.js';

export function load() {
	return {
		restaurants: getRestaurants(),
		restaurantCounts: getRestaurantCounts()
	};
}
