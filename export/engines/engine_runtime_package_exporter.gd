# EngineRuntimePackageExporter -- Emits self-contained Godot, Unity, and Unreal-style runtime packages.
class_name EngineRuntimePackageExporter
extends RefCounted

const RuntimeContractBuilderScript = preload("res://runtime_plugin/preview/runtime_contract_builder.gd")
const RuntimePackageScript = preload("res://export/project_format/runtime_package.gd")
const RuntimeQaSuiteScript = preload("res://quality/gameplay/runtime_qa_suite.gd")


func export_all(manifest: Dictionary, production_data: Dictionary, output_directory: String, targets: Array = ["godot", "unity", "unreal"]) -> Dictionary:
	var contract := RuntimeContractBuilderScript.build(manifest, production_data)
	var validation := RuntimeContractBuilderScript.validate(contract)
	if not bool(validation.get("valid", false)): return {"success": false, "errors": validation.get("errors", []), "validation": validation}
	var root := output_directory.strip_edges()
	if root.is_empty(): return {"success": false, "errors": ["Choose an output directory."], "validation": validation}
	if DirAccess.make_dir_recursive_absolute(_absolute(root)) != OK: return {"success": false, "errors": ["Could not create runtime export directory."], "validation": validation}
	var package := RuntimePackageScript.create(contract, {"contract_hash": str(contract.get("content_hash", "")), "authored_parameters_only": true})
	var package_report := RuntimePackageScript.save(package, root.path_join("character.chrpack"))
	if not bool(package_report.get("success", false)): return package_report
	var contract_path := root.path_join("character.runtime.json")
	if not _write_json(contract_path, contract): return {"success": false, "errors": ["Could not write runtime contract."], "validation": validation}
	var results: Dictionary = {}
	for raw_target in targets:
		var target := str(raw_target).to_lower()
		match target:
			"godot": results[target] = _godot(root, contract)
			"unity": results[target] = _unity(root, contract)
			"unreal": results[target] = _unreal(root, contract)
			_: results[target] = {"success": false, "errors": ["Unsupported runtime target: " + target]}
	var success := true
	for target in results: success = success and bool((results[target] as Dictionary).get("success", false))
	var runtime_comparison := RuntimeQaSuiteScript.new().compare_exported_package(contract, str(package_report.get("path", "")))
	var report := {"success": success, "root": root, "contract": contract_path, "package": package_report.get("path", ""), "targets": results, "validation": validation, "runtime_comparison": runtime_comparison, "comparison_key": str(contract.get("content_hash", ""))}
	_write_json(root.path_join("runtime_export_report.json"), report)
	var export_validation := validate_export(root, targets)
	report["export_validation"] = export_validation
	report["success"] = success and bool(runtime_comparison.get("matches", false)) and bool(export_validation.get("valid", false))
	_write_json(root.path_join("runtime_export_report.json"), report)
	return report


func validate_export(root: String, targets: Array = ["godot", "unity", "unreal"]) -> Dictionary:
	var errors: Array = []
	for file_path in [root.path_join("character.chrpack"), root.path_join("character.runtime.json"), root.path_join("runtime_export_report.json")]:
		if not FileAccess.file_exists(_absolute(file_path)): errors.append("Missing export file: " + file_path)
	var canonical := _read_json(root.path_join("character.runtime.json"))
	if canonical.is_empty(): errors.append("Canonical runtime contract is unreadable.")
	var expected_hash := str(canonical.get("content_hash", ""))
	if expected_hash.is_empty() and not canonical.is_empty(): errors.append("Canonical runtime contract has no content hash.")
	for raw_target in targets:
		var target := str(raw_target).to_lower()
		var sample: String = str({"godot": root.path_join("godot/sample_character_controller.gd"), "unity": root.path_join("unity/Assets/CharacterRuntime/Scripts/CharacterRuntimeController.cs"), "unreal": root.path_join("unreal/Source/CharacterRuntime/CharacterRuntimeComponent.h")}.get(target, ""))
		if sample.is_empty() or not FileAccess.file_exists(_absolute(sample)): errors.append("Missing %s sample controller." % target)
		var target_contract: String = str({"godot": root.path_join("godot/character.runtime.json"), "unity": root.path_join("unity/Assets/CharacterRuntime/StreamingAssets/character.runtime.json"), "unreal": root.path_join("unreal/Content/CharacterRuntime/character.runtime.json")}.get(target, ""))
		if target_contract.is_empty():
			errors.append("Unsupported runtime target: " + target)
			continue
		var target_data := _read_json(target_contract)
		if target_data.is_empty(): errors.append("Missing or unreadable %s runtime JSON." % target)
		elif str(target_data.get("content_hash", "")) != expected_hash: errors.append("%s runtime JSON does not match the canonical contract." % target)
		if target == "godot" and not FileAccess.file_exists(_absolute(root.path_join("godot/project.godot"))): errors.append("Godot runtime sample project is missing.")
	return {"valid": errors.is_empty(), "errors": errors, "content_hash": expected_hash}


func _godot(root: String, contract: Dictionary) -> Dictionary:
	var folder := root.path_join("godot")
	if not _write_json(folder.path_join("character.runtime.json"), contract): return {"success": false, "errors": ["Could not write Godot runtime JSON."]}
	var controller := """extends Node2D

# Reference consumer for the exported, data-only contract.
const CharacterPlayer2DScript = preload("res://addons/modular_character_runtime/runtime/character_player_2d.gd")

@export_file("*.json") var runtime_contract_path := "res://character.runtime.json"
var runtime_player: Node2D


func _ready() -> void:
	runtime_player = CharacterPlayer2DScript.new()
	add_child(runtime_player)
	var contract := _load_contract()
	if not contract.is_empty(): runtime_player.load_package({"content": contract})


func set_runtime_input(parameters: Dictionary, equipment: Dictionary = {}) -> Dictionary:
	for parameter_id in parameters: runtime_player.set_parameter(str(parameter_id), parameters[parameter_id])
	for slot_id in equipment: runtime_player.equip(str(slot_id), equipment[slot_id])
	return runtime_player.get_debug_snapshot()


func _load_contract() -> Dictionary:
	if runtime_contract_path.is_empty() or not FileAccess.file_exists(runtime_contract_path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(runtime_contract_path))
	return parsed as Dictionary if parsed is Dictionary and str((parsed as Dictionary).get("contract", "")) == "modular_character_runtime" else {}
"""
	var project := "; Generated runtime sample. Open this folder directly in Godot.\nconfig_version=5\n\n[application]\nconfig/name=\"Character Runtime Sample\"\nrun/main_scene=\"res://sample.tscn\"\n\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n"
	var scene := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://sample_character_controller.gd\" id=\"1\"]\n\n[node name=\"CharacterRuntimeSample\" type=\"Node2D\"]\nscript = ExtResource(\"1\")\n"
	if not _write_text(folder.path_join("sample_character_controller.gd"), controller): return {"success": false, "errors": ["Could not write Godot sample controller."]}
	var copied: bool = _copy_tree("res://addons/modular_character_runtime", folder.path_join("addons/modular_character_runtime"))
	var sample_files := _write_text(folder.path_join("project.godot"), project) and _write_text(folder.path_join("sample.tscn"), scene)
	return {"success": copied and sample_files, "folder": folder, "sample_controller": folder.path_join("sample_character_controller.gd"), "errors": [] if copied and sample_files else ["Could not complete Godot runtime package."]}


func _unity(root: String, contract: Dictionary) -> Dictionary:
	var folder := root.path_join("unity/Assets/CharacterRuntime")
	if not _write_json(folder.path_join("StreamingAssets/character.runtime.json"), contract): return {"success": false, "errors": ["Could not write Unity runtime JSON."]}
	var controller := """using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace ModularCharacterRuntime
{
    [Serializable]
    internal sealed class RuntimeContractHeader
    {
        public string contract;
        public string contract_version;
        public string content_hash;
    }

    // Reference bridge: host gameplay reads the same JSON consumed by QA/export.
    public sealed class CharacterRuntimeController : MonoBehaviour
    {
        [SerializeField] private TextAsset runtimeContract;
        [SerializeField] private string streamingAssetFile = "character.runtime.json";
        private readonly Dictionary<string, string> parameters = new Dictionary<string, string>();
        private readonly Dictionary<string, string> equipment = new Dictionary<string, string>();

        public string ContractJson { get; private set; }
        public string ContractHash { get; private set; }
        public bool IsLoaded => !string.IsNullOrEmpty(ContractHash);

        private void Awake() => LoadRuntimeContract();

        public bool LoadRuntimeContract()
        {
            ContractJson = runtimeContract != null ? runtimeContract.text : LoadStreamingAsset();
            if (string.IsNullOrEmpty(ContractJson)) return false;
            var header = JsonUtility.FromJson<RuntimeContractHeader>(ContractJson);
            if (header == null || header.contract != "modular_character_runtime") return false;
            ContractHash = header.content_hash;
            return !string.IsNullOrEmpty(ContractHash);
        }

        public void SetRuntimeInput(string parameterId, string jsonValue)
        {
            parameters[parameterId] = jsonValue;
            SendMessage("OnCharacterRuntimeInput", parameterId, SendMessageOptions.DontRequireReceiver);
        }

        public void Equip(string slotId, string itemId)
        {
            equipment[slotId] = itemId;
            SendMessage("OnCharacterEquipmentChanged", slotId, SendMessageOptions.DontRequireReceiver);
        }

        public bool TryGetRuntimeInput(string parameterId, out string jsonValue) => parameters.TryGetValue(parameterId, out jsonValue);
        public bool TryGetEquipment(string slotId, out string itemId) => equipment.TryGetValue(slotId, out itemId);

        private string LoadStreamingAsset()
        {
            var path = Path.Combine(Application.streamingAssetsPath, streamingAssetFile);
            return File.Exists(path) ? File.ReadAllText(path) : string.Empty;
        }
    }
}
"""
	var readme := "# Unity runtime package\n\nCopy `Assets/CharacterRuntime` into a Unity project. `StreamingAssets/character.runtime.json` is the canonical data contract. `CharacterRuntimeController` loads and validates its header, retains state/equipment input, and exposes integration hooks for the game's animator, collision, and VFX systems. Use the platform-appropriate StreamingAssets loader on platforms where `File.ReadAllText` is unavailable.\n"
	return {"success": _write_text(folder.path_join("Scripts/CharacterRuntimeController.cs"), controller) and _write_text(folder.path_join("README.md"), readme), "folder": folder, "sample_controller": folder.path_join("Scripts/CharacterRuntimeController.cs"), "errors": []}


func _unreal(root: String, contract: Dictionary) -> Dictionary:
	var folder := root.path_join("unreal")
	if not _write_json(folder.path_join("Content/CharacterRuntime/character.runtime.json"), contract): return {"success": false, "errors": ["Could not write Unreal runtime JSON."]}
	var header := """#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "CharacterRuntimeComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FCharacterRuntimeInputChanged, const FString&, ParameterId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FCharacterRuntimeEquipmentChanged, const FString&, SlotId);

UCLASS(ClassGroup=(Character), meta=(BlueprintSpawnableComponent))
class UCharacterRuntimeComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UCharacterRuntimeComponent();
	virtual void BeginPlay() override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category="Character Runtime")
	FString RuntimeContractRelativePath = TEXT("CharacterRuntime/character.runtime.json");

	UPROPERTY(BlueprintAssignable, Category="Character Runtime")
	FCharacterRuntimeInputChanged OnRuntimeInputChanged;
	UPROPERTY(BlueprintAssignable, Category="Character Runtime")
	FCharacterRuntimeEquipmentChanged OnEquipmentChanged;

	UFUNCTION(BlueprintCallable, Category="Character Runtime") bool LoadRuntimeContract();
	UFUNCTION(BlueprintCallable, Category="Character Runtime") void SetRuntimeInput(const FString& ParameterId, const FString& JsonValue);
	UFUNCTION(BlueprintCallable, Category="Character Runtime") void Equip(const FString& SlotId, const FString& ItemId);
	UFUNCTION(BlueprintPure, Category="Character Runtime") FString GetContractHash() const { return ContractHash; }

private:
	FString ContractHash;
	TMap<FString, FString> RuntimeParameters;
	TMap<FString, FString> Equipment;
};
"""
	var source := """#include "CharacterRuntimeComponent.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

UCharacterRuntimeComponent::UCharacterRuntimeComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void UCharacterRuntimeComponent::BeginPlay()
{
	Super::BeginPlay();
	LoadRuntimeContract();
}

bool UCharacterRuntimeComponent::LoadRuntimeContract()
{
	FString Json;
	const FString Path = FPaths::ProjectContentDir() / RuntimeContractRelativePath;
	if (!FFileHelper::LoadFileToString(Json, *Path)) return false;
	TSharedPtr<FJsonObject> Contract;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Json);
	if (!FJsonSerializer::Deserialize(Reader, Contract) || !Contract.IsValid()) return false;
	FString ContractType;
	if (!Contract->TryGetStringField(TEXT("contract"), ContractType) || ContractType != TEXT("modular_character_runtime")) return false;
	if (!Contract->TryGetStringField(TEXT("content_hash"), ContractHash)) return false;
	return !ContractHash.IsEmpty();
}

void UCharacterRuntimeComponent::SetRuntimeInput(const FString& ParameterId, const FString& JsonValue)
{
	RuntimeParameters.Add(ParameterId, JsonValue);
	OnRuntimeInputChanged.Broadcast(ParameterId);
}

void UCharacterRuntimeComponent::Equip(const FString& SlotId, const FString& ItemId)
{
	Equipment.Add(SlotId, ItemId);
	OnEquipmentChanged.Broadcast(SlotId);
}
"""
	var readme := "# Unreal runtime package\n\nStage `Content/CharacterRuntime/character.runtime.json` as a non-asset file, add `CharacterRuntimeComponent` to the consuming actor, and call `LoadRuntimeContract`. The sample validates the canonical contract/header and exposes Blueprint input/equipment hooks. The JSON holds authored runtime parameters, never baked secondary-motion art.\n"
	return {"success": _write_text(folder.path_join("Source/CharacterRuntime/CharacterRuntimeComponent.h"), header) and _write_text(folder.path_join("Source/CharacterRuntime/CharacterRuntimeComponent.cpp"), source) and _write_text(folder.path_join("README.md"), readme), "folder": folder, "sample_controller": folder.path_join("Source/CharacterRuntime/CharacterRuntimeComponent.h"), "errors": []}


func _copy_tree(source: String, destination: String) -> bool:
	var source_absolute := _absolute(source)
	var destination_absolute := _absolute(destination)
	var directory := DirAccess.open(source_absolute)
	if directory == null or DirAccess.make_dir_recursive_absolute(destination_absolute) != OK: return false
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child_source := source_absolute.path_join(entry)
			var child_destination := destination_absolute.path_join(entry)
			if directory.current_is_dir():
				if not _copy_tree(child_source, child_destination): directory.list_dir_end(); return false
			elif DirAccess.copy_absolute(child_source, child_destination) != OK:
				directory.list_dir_end(); return false
		entry = directory.get_next()
	directory.list_dir_end()
	return true


func _write_json(path: String, data: Dictionary) -> bool:
	return _write_text(path, JSON.stringify(data, "\t", true, false))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(_absolute(path)): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_absolute(path)))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_text(path: String, value: String) -> bool:
	var absolute := _absolute(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: return false
	file.store_string(value)
	file.close()
	return true


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
