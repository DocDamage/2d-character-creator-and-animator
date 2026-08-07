# AssetBrowser — UI panel for searching, browsing, filtering, and selecting assets
class_name AssetBrowser
extends Control

const AssetReportsScript = preload("res://core/assets/asset_reports.gd")

signal asset_selected(asset_id: String, asset_data: Dictionary)
signal asset_double_clicked(asset_id: String)

@onready var search_input: LineEdit = $VBox/Header/SearchInput
@onready var category_select: OptionButton = $VBox/Header/FilterRow/CategorySelect
@onready var favorites_toggle: CheckBox = $VBox/Header/FilterRow/FavoritesToggle
@onready var item_grid: ItemList = $VBox/Content/ItemGrid
@onready var details_label: Label = $VBox/Footer/DetailsLabel

var _registry: AssetRegistry
var _thumbnail_cache: ThumbnailCache
var _displayed_assets: Array = []
var _selected_asset_id: String = ""


func setup(p_registry: AssetRegistry, p_thumbnail_cache: ThumbnailCache) -> void:
	_disconnect_registry()
	_registry = p_registry
	_thumbnail_cache = p_thumbnail_cache
	_selected_asset_id = ""
	if _registry != null:
		_registry.asset_registered.connect(_on_registry_changed)
		_registry.asset_unregistered.connect(_on_registry_changed)
		_registry.asset_updated.connect(_on_registry_changed)
	_populate_category_options()
	if _registry != null:
		refresh()
	else:
		_displayed_assets.clear()
		if item_grid != null: item_grid.clear()
		if details_label != null: details_label.text = "No project assets loaded"


func _disconnect_registry() -> void:
	if _registry == null: return
	for signal_name in [&"asset_registered", &"asset_unregistered", &"asset_updated"]:
		var source_signal: Signal = _registry.get(signal_name)
		if source_signal.is_connected(_on_registry_changed): source_signal.disconnect(_on_registry_changed)


func _ready() -> void:
	if search_input != null:
		search_input.text_changed.connect(func(_text: String): refresh())
	if category_select != null:
		category_select.item_selected.connect(func(_idx: int): refresh())
	if favorites_toggle != null:
		favorites_toggle.toggled.connect(func(_toggled: bool): refresh())
	if item_grid != null:
		item_grid.item_selected.connect(_on_item_selected)
		item_grid.item_activated.connect(_on_item_activated)


func refresh() -> void:
	if _registry == null or item_grid == null:
		return
	
	item_grid.clear()
	var all_assets := _registry.list_assets()
	var query := search_input.text if search_input != null else ""
	var cat_idx := category_select.selected if category_select != null else 0
	var category: String = str(category_select.get_item_metadata(cat_idx)) if category_select != null and cat_idx >= 0 else ""
	var fav_only := favorites_toggle.button_pressed if favorites_toggle != null else false
	
	_displayed_assets = AssetFilterService.filter_assets(all_assets, query, category, "", fav_only)
	
	for i in range(_displayed_assets.size()):
		var asset: Dictionary = _displayed_assets[i]
		var asset_id: String = asset.get("asset_id", "")
		var name: String = asset.get("name", "Unnamed")
		
		var icon: ImageTexture = null
		if _thumbnail_cache != null:
			icon = _thumbnail_cache.get_thumbnail(asset)
		
		item_grid.add_item(name, icon)
		item_grid.set_item_metadata(i, asset_id)
		if asset.get("favorite", false):
			item_grid.set_item_custom_fg_color(i, Color.GOLD)
	if details_label != null and _selected_asset_id.is_empty():
		var report: Dictionary = AssetReportsScript.generate_report(_registry)
		var warnings: Array[String] = []
		if int(report.get("duplicate_groups", 0)) > 0:
			warnings.append("%d duplicate group%s" % [int(report.get("duplicate_groups", 0)), "s" if int(report.get("duplicate_groups", 0)) != 1 else ""])
		if int(report.get("missing_count", 0)) > 0:
			warnings.append("%d missing file%s" % [int(report.get("missing_count", 0)), "s" if int(report.get("missing_count", 0)) != 1 else ""])
		details_label.text = "%d project asset%s%s" % [int(report.get("total_assets", 0)), "s" if int(report.get("total_assets", 0)) != 1 else "", " · " + ", ".join(warnings) if not warnings.is_empty() else " · no duplicate or missing artwork"]


func _populate_category_options() -> void:
	if category_select == null:
		return
	category_select.clear()
	category_select.add_item("All Categories")
	category_select.set_item_metadata(0, "")
	category_select.add_item("Source Art")
	category_select.set_item_metadata(1, AssetRegistry.CATEGORY_SOURCE_ART)
	category_select.add_item("Reference")
	category_select.set_item_metadata(2, AssetRegistry.CATEGORY_REFERENCE)
	category_select.add_item("Audio")
	category_select.set_item_metadata(3, AssetRegistry.CATEGORY_AUDIO)
	category_select.add_item("Preview")
	category_select.set_item_metadata(4, AssetRegistry.CATEGORY_PREVIEW)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _displayed_assets.size():
		return
	var asset: Dictionary = _displayed_assets[index]
	_selected_asset_id = asset.get("asset_id", "")
	
	if details_label != null:
		details_label.text = "%s | %dx%d | %s" % [
			asset.get("name", ""),
			asset.get("width", 0),
			asset.get("height", 0),
			asset.get("category", "")
		]
	asset_selected.emit(_selected_asset_id, asset)


func _on_item_activated(index: int) -> void:
	if index >= 0 and index < _displayed_assets.size():
		var asset_id: String = _displayed_assets[index].get("asset_id", "")
		asset_double_clicked.emit(asset_id)


func _on_registry_changed(_a: Variant = null, _b: Variant = null) -> void:
	refresh()
