mod tests {
    use stark_brawl::models::trap::{TrapTrait, TrapType, Vec2, create_trap, ZeroableTrapTrait};
    use starknet::{ContractAddress, contract_address_const};

    fn get_test_owner() -> ContractAddress {
        contract_address_const::<0x12345>()
    }

    #[test]
    fn test_trap_initialization() {
        let owner = get_test_owner();
        let trap = create_trap(1, owner, 5_u32, 10_u32, 2_u32, 30_u16, TrapType::Poison);

        assert(trap.trap_id == 1, 'Trap ID mismatch');
        assert(trap.owner == owner, 'Owner mismatch');
        assert(trap.position.x == 5_u32, 'X position mismatch');
        assert(trap.position.y == 10_u32, 'Y position mismatch');
        assert(trap.trigger_radius == 2, 'Trigger radius mismatch');
        assert(trap.damage == 30, 'Damage mismatch');
        assert(trap.trap_type == TrapType::Poison, 'Trap type mismatch');
        assert(trap.is_active, 'Trap should start active');
    }

    #[test]
    fn test_enemy_triggering_trap_at_exact_position() {
        let owner = get_test_owner();
        let trap = create_trap(1, owner, 10_u32, 10_u32, 3_u32, 50_u16, TrapType::Explosive);
        
        // Enemy at same position as trap
        let enemy_pos = Vec2 { x: 10_u32, y: 10_u32 };
        assert(trap.check_trigger(enemy_pos), 'Should trigger at same position');
    }

    #[test]
    fn test_enemy_triggering_trap_within_radius() {
        let owner = get_test_owner();
        let trap = create_trap(2, owner, 15_u32, 20_u32, 4_u32, 40_u16, TrapType::Electric);
        
        // Test multiple positions within radius
        let positions_within_radius: Array<Vec2> = array![
            Vec2 { x: 16_u32, y: 21_u32 }, // Distance = 2
            Vec2 { x: 18_u32, y: 20_u32 }, // Distance = 3
            Vec2 { x: 15_u32, y: 24_u32 }, // Distance = 4
            Vec2 { x: 11_u32, y: 20_u32 }, // Distance = 4
        ];

        let mut i = 0;
        loop {
            if i >= positions_within_radius.len() {
                break;
            }
            let pos = *positions_within_radius.at(i);
            assert(trap.check_trigger(pos), 'Should trigger within radius');
            i += 1;
        };
    }

    #[test]
    fn test_enemy_not_triggering_trap_outside_radius() {
        let owner = get_test_owner();
        let trap = create_trap(3, owner, 10_u32, 10_u32, 2_u32, 35_u16, TrapType::Freezing);
        
        // Test positions outside radius
        let positions_outside_radius: Array<Vec2> = array![
            Vec2 { x: 13_u32, y: 11_u32 }, // Distance = 4
            Vec2 { x: 5_u32, y: 10_u32 },  // Distance = 5
            Vec2 { x: 10_u32, y: 15_u32 }, // Distance = 5
            Vec2 { x: 15_u32, y: 15_u32 }, // Distance = 10
        ];

        let mut i = 0;
        loop {
            if i >= positions_outside_radius.len() {
                break;
            }
            let pos = *positions_outside_radius.at(i);
            assert(!trap.check_trigger(pos), 'Should not trigger outside');
            i += 1;
        };
    }

    #[test]
    fn test_enemy_triggering_sequence() {
        let owner = get_test_owner();
        let mut trap = create_trap(4, owner, 8_u32, 12_u32, 3_u32, 60_u16, TrapType::Explosive);
        
        // Enemy approaches the trap
        let enemy_pos = Vec2 { x: 10_u32, y: 12_u32 }; // Distance = 2, within radius
        
        // Check if trap would trigger
        assert(trap.check_trigger(enemy_pos), 'Trap should detect enemy');
        assert(trap.is_active, 'Trap should be active before');
        
        // Trigger the trap
        let damage_dealt = trap.trigger();
        assert(damage_dealt == 60, 'Should deal full damage');
        assert(!trap.is_active, 'Trap should be inactive after');
        
        // Verify trap won't trigger again
        assert(!trap.check_trigger(enemy_pos), 'Inactive trap no trigger');
        let second_damage = trap.trigger();
        assert(second_damage == 0, 'No damage from inactive trap');
    }

    #[test]
    fn test_multiple_enemies_single_trap() {
        let owner = get_test_owner();
        let mut trap = create_trap(5, owner, 0_u32, 0_u32, 5_u32, 25_u16, TrapType::Poison);
        
        // First enemy triggers trap
        let enemy1_pos = Vec2 { x: 2_u32, y: 3_u32 }; // Distance = 5, at edge
        assert(trap.check_trigger(enemy1_pos), 'First enemy should trigger');
        
        let damage1 = trap.trigger();
        assert(damage1 == 25, 'Should deal damage to first');
        assert(!trap.is_active, 'Trap consumed after first');
        
        // Second enemy cannot trigger the same trap
        let enemy2_pos = Vec2 { x: 1_u32, y: 1_u32 }; // Distance = 2, well within radius
        assert(!trap.check_trigger(enemy2_pos), 'No trigger on consumed trap');
        
        let damage2 = trap.trigger();
        assert(damage2 == 0, 'No damage to second enemy');
    }

    #[test]
    fn test_different_trap_types_behavior() {
        let owner = get_test_owner();
        
        // Create different trap types
        let mut explosive_trap = create_trap(10, owner, 0_u32, 0_u32, 3_u32, 80_u16, TrapType::Explosive);
        let mut poison_trap = create_trap(11, owner, 10_u32, 10_u32, 4_u32, 20_u16, TrapType::Poison);
        let mut electric_trap = create_trap(12, owner, 20_u32, 20_u32, 2_u32, 45_u16, TrapType::Electric);
        let mut freezing_trap = create_trap(13, owner, 30_u32, 30_u32, 5_u32, 15_u16, TrapType::Freezing);
        
        let enemy_pos = Vec2 { x: 1_u32, y: 1_u32 };
        
        // Test explosive trap
        assert(explosive_trap.check_trigger(enemy_pos), 'Enemy should trigger explosive');
        let explosive_damage = explosive_trap.trigger();
        assert(explosive_damage == 80, 'Explosive should deal 80');
        
        // Test poison trap (enemy at different position)
        let poison_enemy_pos = Vec2 { x: 12_u32, y: 12_u32 };
        assert(poison_trap.check_trigger(poison_enemy_pos), 'Enemy should trigger poison');
        let poison_damage = poison_trap.trigger();
        assert(poison_damage == 20, 'Poison should deal 20');
        
        // Test electric trap
        let electric_enemy_pos = Vec2 { x: 21_u32, y: 20_u32 };
        assert(electric_trap.check_trigger(electric_enemy_pos), 'Enemy should trigger electric');
        let electric_damage = electric_trap.trigger();
        assert(electric_damage == 45, 'Electric should deal 45');
        
        // Test freezing trap
        let freezing_enemy_pos = Vec2 { x: 33_u32, y: 32_u32 };
        assert(freezing_trap.check_trigger(freezing_enemy_pos), 'Enemy should trigger freezing');
        let freezing_damage = freezing_trap.trigger();
        assert(freezing_damage == 15, 'Freezing should deal 15');
    }

    #[test]
    fn test_trap_activation_deactivation() {
        let owner = get_test_owner();
        let mut trap = create_trap(6, owner, 5_u32, 5_u32, 2_u32, 40_u16, TrapType::Electric);
        
        assert(trap.is_active, 'Trap should start active');
        
        // Deactivate trap
        trap.deactivate();
        assert(!trap.is_active, 'Trap should be inactive');
        
        // Enemy should not trigger inactive trap
        let enemy_pos = Vec2 { x: 5_u32, y: 5_u32 };
        assert(!trap.check_trigger(enemy_pos), 'Inactive trap no trigger');
        
        // Reactivate trap
        trap.activate();
        assert(trap.is_active, 'Trap should be active again');
        assert(trap.check_trigger(enemy_pos), 'Reactivated trap should trigger');
    }

    #[test] 
    fn test_trap_edge_cases() {
        let owner = get_test_owner();
        
        // Test trap with zero radius
        let zero_radius_trap = create_trap(7, owner, 10_u32, 10_u32, 0_u32, 50_u16, TrapType::Explosive);
        let enemy_at_trap = Vec2 { x: 10_u32, y: 10_u32 };
        let enemy_adjacent = Vec2 { x: 11_u32, y: 10_u32 };
        
        assert(zero_radius_trap.check_trigger(enemy_at_trap), 'Should trigger at exact pos');
        assert(!zero_radius_trap.check_trigger(enemy_adjacent), 'No trigger adjacent zero');
        
        // Test trap with very large radius
        let large_radius_trap = create_trap(8, owner, 0_u32, 0_u32, 100_u32, 10_u16, TrapType::Poison);
        let far_enemy = Vec2 { x: 50_u32, y: 49_u32 }; // Distance = 99
        assert(large_radius_trap.check_trigger(far_enemy), 'Should trigger with large');
    }

    #[test]
    fn test_trap_distance_calculation() {
        let owner = get_test_owner();
        let trap = create_trap(9, owner, 10_u32, 10_u32, 5_u32, 25_u16, TrapType::Freezing);
        
        // Test various distance calculations with Manhattan distance
        let test_cases: Array<(Vec2, bool)> = array![
            (Vec2 { x: 15_u32, y: 10_u32 }, true),  // Distance = 5 (exact edge)
            (Vec2 { x: 12_u32, y: 13_u32 }, true),  // Distance = 5 (exact edge)
            (Vec2 { x: 16_u32, y: 11_u32 }, false), // Distance = 7 (outside)
            (Vec2 { x: 8_u32, y: 7_u32 }, true),    // Distance = 5 (exact edge)
            (Vec2 { x: 5_u32, y: 10_u32 }, true),   // Distance = 5 (exact edge)
            (Vec2 { x: 10_u32, y: 5_u32 }, true),   // Distance = 5 (exact edge)
            (Vec2 { x: 16_u32, y: 16_u32 }, false), // Distance = 12 (outside)
        ];

        let mut i = 0;
        loop {
            if i >= test_cases.len() {
                break;
            }
            let (pos, should_trigger) = *test_cases.at(i);
            let result = trap.check_trigger(pos);
            assert(result == should_trigger, 'Distance calculation wrong');
            i += 1;
        };
    }
} 