# RigTemplates — Preset skeletal templates for Humanoid, Biped, Quadruped, and Pixel characters
class_name RigTemplates
extends RefCounted


static func create_humanoid_template() -> Dictionary:
	var rig := RigSchema.create_empty_rig("rig_humanoid", "Humanoid Standard Rig")
	var bm := BoneManager.new()
	bm.initialize(rig)
	
	var root := bm.add_bone("root", "", 40.0)
	var pelvis := bm.add_bone("pelvis", root.get("id", ""), 30.0)
	var spine := bm.add_bone("spine", pelvis.get("id", ""), 50.0)
	var chest := bm.add_bone("chest", spine.get("id", ""), 40.0)
	var neck := bm.add_bone("neck", chest.get("id", ""), 20.0)
	var head := bm.add_bone("head", neck.get("id", ""), 30.0)
	
	# Left Arm
	var u_arm_l := bm.add_bone("upper_arm_l", chest.get("id", ""), 45.0)
	var l_arm_l := bm.add_bone("lower_arm_l", u_arm_l.get("id", ""), 40.0)
	var hand_l := bm.add_bone("hand_l", l_arm_l.get("id", ""), 20.0)
	
	# Right Arm
	var u_arm_r := bm.add_bone("upper_arm_r", chest.get("id", ""), 45.0)
	var l_arm_r := bm.add_bone("lower_arm_r", u_arm_r.get("id", ""), 40.0)
	var hand_r := bm.add_bone("hand_r", l_arm_r.get("id", ""), 20.0)
	
	# Left Leg
	var u_leg_l := bm.add_bone("upper_leg_l", pelvis.get("id", ""), 50.0)
	var l_leg_l := bm.add_bone("lower_leg_l", u_leg_l.get("id", ""), 45.0)
	var foot_l := bm.add_bone("foot_l", l_leg_l.get("id", ""), 25.0)
	
	# Right Leg
	var u_leg_r := bm.add_bone("upper_leg_r", pelvis.get("id", ""), 50.0)
	var l_leg_r := bm.add_bone("lower_leg_r", u_leg_r.get("id", ""), 45.0)
	var foot_r := bm.add_bone("foot_r", l_leg_r.get("id", ""), 25.0)
	
	# Add Slots
	var sm := SlotManager.new()
	sm.initialize(rig)
	sm.add_slot("slot_head", head.get("id", ""))
	sm.add_slot("slot_body", chest.get("id", ""))
	sm.add_slot("slot_hand_l", hand_l.get("id", ""))
	sm.add_slot("slot_hand_r", hand_r.get("id", ""))
	
	return rig


static func create_quadruped_template() -> Dictionary:
	var rig := RigSchema.create_empty_rig("rig_quadruped", "Quadruped Standard Rig")
	var bm := BoneManager.new()
	bm.initialize(rig)
	
	var root := bm.add_bone("root", "", 40.0)
	var spine := bm.add_bone("spine", root.get("id", ""), 60.0)
	var head := bm.add_bone("head", spine.get("id", ""), 35.0)
	var tail := bm.add_bone("tail", root.get("id", ""), 40.0)
	
	return rig
