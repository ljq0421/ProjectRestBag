from __future__ import annotations

from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]

EXPECTED_VARIATIONS = {
    "scenes/Main.tscn": {
        "GlobalPopupBackdrop": "",
        "OverlayCloseButton": "",
    },
    "scenes/ui/overlays/automation_overlay.tscn": {
        "OutputCapacity1Button": "DessertRedActionButton",
        "OfflineDuration1Button": "DessertRedActionButton",
        "OutputCapacity2Button": "DessertRedActionButton",
        "OfflineDuration2Button": "DessertRedActionButton",
        "OutputCapacityAllButton": "DessertRedActionButton",
        "KitchenDevices2Button": "DessertRedActionButton",
        "KitchenRules3Button": "DessertRedActionButton",
        "KitchenPriorityButton": "DessertRedActionButton",
        "KitchenInventoryPolicyButton": "DessertRedActionButton",
        "KitchenAllButton": "DessertRedActionButton",
        "PauseAllButton": "DessertRedActionButton",
    },
    "scenes/ui/overlays/automation_report_dialog.tscn": {
        "NavigateButton": "DessertRedActionButton",
        "CloseButton": "",
    },
    "scenes/ui/overlays/catalog_overlay.tscn": {
        "CatalogClaimAllRewardsButton": "DessertRedActionButton",
        "CatalogPrevButton": "",
        "CatalogNextButton": "",
        "CatalogMilestone25Button": "",
    },
    "scenes/ui/overlays/catalog_recipe_card.tscn": {
        "CatalogRecipeCard": "DessertItemSlot",
    },
    "scenes/ui/pages/device_growth_center_page.tscn": {
        "UpgradeButton": "DessertRedActionButton",
        "CatalogButton": "DessertSecondaryButton",
    },
    "scenes/ui/overlays/inventory_overlay.tscn": {
        "InventoryRestockButton": "DessertRedActionButton",
        "InventoryBatchListButton": "DessertRedActionButton",
        "InventorySellExtraButton": "DessertRedActionButton",
        "InventoryOrganizeButton": "DessertRedActionButton",
        "InventoryPrevButton": "",
        "InventoryNextButton": "",
    },
    "scenes/ui/overlays/inventory_product_cell.tscn": {
        "InventoryProductCell": "DessertItemSlot",
    },
    "scenes/ui/overlays/purchase_receipt_dialog.tscn": {
        "ReceiptCloseButton": "DessertLegacyPrimaryButton",
    },
    "scenes/ui/overlays/showcase_round_settlement_dialog.tscn": {
        "CloseButton": "",
    },
    "scenes/ui/overlays/showcase_rulebook_dialog.tscn": {
        "CloseButton": "",
    },
    "scenes/ui/overlays/recipe_growth_detail_panel.tscn": {
        "ChooseTraitButton": "DessertRedActionButton",
    },
    "scenes/ui/overlays/task_detail_content.tscn": {
        "TaskActionButton": "DessertRedActionButton",
    },
    "scenes/ui/overlays/task_overlay.tscn": {
        "TaskClaimAllRewardsButton": "DessertRedActionButton",
    },
    "scenes/ui/overlays/task_filter_button.tscn": {
        "TaskFilterButton": "DessertRedToggleButton",
    },
    "scenes/ui/overlays/task_entry_button.tscn": {
        "TaskEntryButton": "",
    },
    "scenes/ui/overlays/tutorial_guide_overlay.tscn": {
        "GrandmaIconButton": "DessertLegacyPrimaryButton",
        "CloseButton": "DessertLegacyPrimaryButton",
    },
    "scenes/ui/pages/kitchen_automation_panel.tscn": {
        "CollapseButton": "",
    },
    "scenes/ui/pages/output_cell.tscn": {
        "OutputCell": "DessertItemSlot",
    },
    "scenes/ui/pages/output_site_region.tscn": {
        "OutputPrevPageButton": "DessertIconButton",
        "OutputNextPageButton": "DessertIconButton",
    },
    "scenes/ui/pages/purchase_quantity_row.tscn": {
        "PurchaseMinusButton": "",
        "PurchasePlusButton": "",
    },
    "scenes/ui/pages/production_workbench.tscn": {
        "BulkActionButton": "DessertSecondaryButton",
        "KitchenScheduleButton": "DessertSecondaryButton",
    },
    "scenes/ui/pages/production_queue_recipe_row.tscn": {
        "ActionButton": "DessertRedButton",
    },
    "scenes/ui/pages/research_input_slot.tscn": {
        "ResearchInputSlot": "DessertContentButton",
    },
    "scenes/ui/pages/storefront_manage_page.tscn": {
        "none": "DessertRedToggleButton",
        "summer": "DessertRedToggleButton",
        "retro": "DessertRedToggleButton",
        "tea": "DessertRedToggleButton",
    },
    "scenes/ui/storefront/showcase_board.tscn": {
        "StartRoundButton": "DessertRedCompactButton",
        "CellToolButton": "DessertRedToggleButton",
        "RowToolButton": "DessertRedToggleButton",
        "ColumnToolButton": "DessertRedToggleButton",
        "ExpansionConfirmButton": "DessertRedCompactButton",
    },
    "scenes/ui/storefront/showcase_slot.tscn": {
        "ShowcaseSlot": "DessertShowcaseSlot",
    },
    "scenes/ui/navigation/workbench_launcher.tscn": {
        "CatalogButton": "DessertLauncherIconButton",
    },
}


def button_variations(scene_path: Path) -> dict[str, str]:
    source = scene_path.read_text(encoding="utf-8")
    close_component_ids = set(
        re.findall(
            r'^\[ext_resource type="PackedScene" path="res://scenes/ui/common/close_image_button\.tscn" id="([^"]+)"\]$',
            source,
            flags=re.MULTILINE,
        )
    )
    variations: dict[str, str] = {}
    for block in re.split(r"(?m)(?=^\[node )", source):
        header = re.match(r'^\[node name="([^"]+)"([^\]]*)\]', block)
        if header is None:
            continue
        attributes = header.group(2)
        is_button = 'type="Button"' in attributes
        if not is_button:
            instance_match = re.search(r'instance=ExtResource\("([^"]+)"\)', attributes)
            is_button = instance_match is not None and instance_match.group(1) in close_component_ids
        if not is_button:
            continue
        variation_match = re.search(
            r'(?m)^theme_type_variation = &"([^"]+)"', block
        )
        variations[header.group(1)] = variation_match.group(1) if variation_match else ""
    return variations


class RedOperationButtonScopeTests(unittest.TestCase):
    def test_included_and_excluded_scene_buttons_keep_expected_variations(self) -> None:
        for relative_path, expected in EXPECTED_VARIATIONS.items():
            actual = button_variations(REPO_ROOT / relative_path)
            for button_name, expected_variation in expected.items():
                self.assertIn(button_name, actual, f"Missing {relative_path}:{button_name}")
                self.assertEqual(
                    actual[button_name],
                    expected_variation,
                    f"Unexpected variation for {relative_path}:{button_name}",
                )


if __name__ == "__main__":
    unittest.main()
