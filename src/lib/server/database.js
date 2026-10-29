import Database from 'better-sqlite3';
import { resolve } from 'node:path';

const database = new Database(
	process.env.DATABASE_PATH ?? resolve(process.cwd(), 'database.sqlite'),
	{ readonly: true, fileMustExist: true }
);

/**
 * @typedef {{
 *   id: number;
 *   slug: string;
 *   name: string;
 *   tagline: string | null;
 *   description: string | null;
 *   price_tier: number;
 *   avg_spend_min: number | null;
 *   avg_spend_max: number | null;
 *   currency: string;
 *   editorial_rating: number | null;
 *   rating_avg: number;
 *   rating_count: number;
 *   phone: string | null;
 *   street_address: string;
 *   postcode: string | null;
 *   neighborhood: string;
 *   city: string;
 *   country_code: string;
 *   latitude: number | null;
 *   longitude: number | null;
 *   list_status: 'ranked' | 'want_to_try' | null;
 *   rank: number | null;
 *   visit_count: number;
 *   listing_status: 'published' | 'pending';
 *   created_at: string;
 *   updated_at: string;
 * }} RestaurantRow
 */

/**
 * @typedef {{ position: number; url: string; caption: string | null; alt_text: string | null }} RestaurantPhoto
 */

/**
 * @typedef {{ slug: string; name: string; kind: 'cuisine' | 'style'; position: number }} RestaurantTag
 */

export function getRestaurants() {
	/** @type {RestaurantRow[]} */
	const rows = database
		.prepare(`
			SELECT *
			FROM restaurants
			ORDER BY
				CASE
					WHEN list_status = 'ranked' THEN 0
					WHEN list_status = 'want_to_try' THEN 1
					ELSE 2
				END,
				rank,
				name COLLATE NOCASE
		`)
		.all();

	if (rows.length === 0) return [];

	const ids = rows.map(({ id }) => id);
	const placeholders = ids.map(() => '?').join(', ');

	/** @type {(RestaurantPhoto & { restaurant_id: number })[]} */
	const photos = database
		.prepare(`
			SELECT restaurant_id, position, url, caption, alt_text
			FROM photos
			WHERE restaurant_id IN (${placeholders})
			ORDER BY restaurant_id, position
		`)
		.all(...ids);

	/** @type {(RestaurantTag & { restaurant_id: number })[]} */
	const tags = database
		.prepare(`
			SELECT
				restaurant_tags.restaurant_id,
				tags.slug,
				tags.name,
				tags.kind,
				restaurant_tags.position
			FROM restaurant_tags
			INNER JOIN tags ON tags.id = restaurant_tags.tag_id
			WHERE restaurant_tags.restaurant_id IN (${placeholders})
			ORDER BY restaurant_tags.restaurant_id, restaurant_tags.position
		`)
		.all(...ids);

	/** @type {Map<number, RestaurantPhoto[]>} */
	const photosByRestaurant = new Map();
	for (const { restaurant_id, ...photo } of photos) {
		const restaurantPhotos = photosByRestaurant.get(restaurant_id) ?? [];
		restaurantPhotos.push(photo);
		photosByRestaurant.set(restaurant_id, restaurantPhotos);
	}

	/** @type {Map<number, RestaurantTag[]>} */
	const tagsByRestaurant = new Map();
	for (const { restaurant_id, ...tag } of tags) {
		const restaurantTags = tagsByRestaurant.get(restaurant_id) ?? [];
		restaurantTags.push(tag);
		tagsByRestaurant.set(restaurant_id, restaurantTags);
	}

	return rows.map((restaurant) => ({
		...restaurant,
		photos: photosByRestaurant.get(restaurant.id) ?? [],
		tags: tagsByRestaurant.get(restaurant.id) ?? []
	}));
}

export function getRestaurantCounts() {
	/** @type {{ total: number; ranked: number; wantToTry: number }} */
	const counts = database
		.prepare(`
			SELECT
				COUNT(*) AS total,
				COUNT(CASE WHEN list_status = 'ranked' THEN 1 END) AS ranked,
				COUNT(CASE WHEN list_status = 'want_to_try' THEN 1 END) AS wantToTry
			FROM restaurants
		`)
		.get();

	return counts;
}
