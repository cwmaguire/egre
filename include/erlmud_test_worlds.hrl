-define(TEST_CONN_HANDLERS, {handlers, [erlmud_handler_test_connection_attack,
                                        ?UNIVERSAL_HANDLERS]}).

-define(WORLD_1, [{room_nw, [{exit, exit_ns},
                             {exit, exit_ew},
                             {character, player},
                             {icon, room},
                             ?ROOM_HANDLERS]},
                  {room_s, [{exit, exit_ns},
                            {icon, room},
                            ?ROOM_HANDLERS]},
                  {room_e, [{exit, exit_ew},
                            {icon, room},
                            ?ROOM_HANDLERS]},
                  {player, [{owner, room_nw},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {exit_ns, [{{room, n}, room_nw},
                             {{room, s}, room_s},
                             {icon, exit},
                             ?EXIT_HANDLERS]},
                  {exit_ew, [{{room, w}, room_nw},
                             {{room, e}, room_e},
                             {is_locked, true},
                             {icon, exit},
                             ?EXIT_HANDLERS]}]).

-define(WORLD_2, [{room, [{player, player},
                          {item, sword},
                          {item, apple},
                          {icon, room},
                          ?ROOM_HANDLERS]},
                  {player, [{owner, room},
                            {item, helmet},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {sword, [{owner, room},
                           {name, <<"sword">>},
                           {icon, weapon},
                           ?ITEM_HANDLERS]},
                  {helmet, [{owner, player},
                            {name, <<"helmet">>},
                            {icon, armor},
                            ?ITEM_HANDLERS]},
                  {apple, [{owner, room},
                           {name, <<"apple">>},
                           {icon, food},
                           ?ITEM_HANDLERS]}]).

-define(WORLD_3, [{room, [{character, player},
                          {character, zombie},
                          {icon, room},
                          ?ROOM_HANDLERS]},

                  {player, [{owner, room},
                            {hitpoints, p_hp},
                            {life, p_life},
                            {attribute, dexterity0},
                            {attack_types, [hand]},
                            %% TODO: why is stamina a first class property
                            %% instead of just an attribute?
                            %% It might not matter what the index of the property
                            %% is if we don't look them up by index
                            {stamina, p_stamina},
                            {body_part, p_hand},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {p_hp, [{hitpoints, 1000},
                          {owner, player},
                          {icon, stat},
                          ?HITPOINTS_HANDLERS]},
                  {p_life, [{is_alive, true},
                            {owner, player},
                            {icon, stat},
                            ?LIFE_HANDLERS]},
                  {p_hand, [{name, <<"hand0">>},
                            {item, p_fist},
                            {owner, player},
                            {max_items, 1},
                            {body_part, hand},
                            {icon, body_part},
                            ?BODY_PART_HANDLERS]},
                  {p_fist, [{attack_damage_modifier, 5},
                            {attack_hit_modifier, 1},
                            {owner, p_hand},
                            {character, player},
                            {wielding_body_parts, [hand]},
                            {body_part, {?PID(p_hand), hand}},
                            {is_attack, true},
                            {resources, [{stamina, 5}]},
                            {icon, body_part},
                            ?ITEM_HANDLERS]},
                  {dexterity0, [{attack_hit_modifier, 1},
                                {defence_hit_modifier, 99},
                                {owner, player},
                                {character, player},
                                {icon, stat},
                                ?ATTRIBUTE_HANDLERS]},
                  {p_stamina, [{owner, player},
                               {type, stamina},
                               {per_tick, 1},
                               {tick_time, 10},
                               {max, 10},
                               {icon, resource},
                               ?RESOURCE_HANDLERS]},

                  {zombie, [{owner, room},
                            {attack_wait, 10},
                            {name, <<"zombie">>},
                            {hitpoints, z_hp},
                            {life, z_life},
                            {attribute, dexterity1},
                            {body_part, z_hand},
                            %% TODO Do something with this
                            %% "melee" can even be an attack command that's
                            %% more specific than just attack:
                            %% "spell zombie"
                            %% "melee zombie"
                            %% "shoot zombie"
                            {attack_types, [melee]},
                            {stamina, z_stamina},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},

                  {z_hand, [{name, <<"left hand">>},
                            {owner, zombie},
                            {body_part, hand},
                            {max_items, 1},
                            {item, sword},
                            {icon, person},
                            ?BODY_PART_HANDLERS]},

                  {z_hp, [{hitpoints, 10},
                          {owner, zombie},
                          {icon, stat},
                          ?HITPOINTS_HANDLERS]},

                  {z_life, [{is_alive, true},
                            {owner, zombie},
                            {icon, stat},
                            ?LIFE_HANDLERS]},

                  {dexterity1, [{attack_hit_modifier, 1},
                                {owner, zombie},
                                {character, zombie},
                                {icon, stat},
                                ?ATTRIBUTE_HANDLERS]},

                  {z_stamina, [{owner, zombie},
                               {type, stamina},
                               {per_tick, 1},
                               {tick_time, 10},
                               {max, 10},
                               {current, 0},
                               {icon, resource},
                               ?RESOURCE_HANDLERS]},

                  {sword, [{attack_damage_modifier, 5},
                           {owner, zombie},
                           {character, zombie},
                           {is_attack, true},
                           {is_auto_attack, true},
                           {resources, [{stamina, 5}]},
                           {wielding_body_parts, [hand]},
                           {body_part, {?PID(z_hand), hand}},
                           {icon, weapon},
                           ?ITEM_HANDLERS]}]).

-define(WORLD_4, [{room, [{player, player}, ?ROOM_HANDLERS]},
                  {player, [{owner, room},
                            {item, helmet},
                            {body_part, head1},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {head1, [{name, <<"head">>},
                           {body_part, head},
                           {owner, player},
                           {icon, body_part},
                           ?BODY_PART_HANDLERS]},
                  {helmet, [{name, <<"helmet">>},
                            {owner, player},
                            {character, player},
                            {attribute, dex_buff},
                            {body_parts, [head]},
                            {icon, armor},
                            ?ITEM_HANDLERS]},
                  {dex_buff, [{name, <<"dex_buff">>},
                              {owner, helmet},
                              {icon, stat},
                              ?ATTRIBUTE_HANDLERS]}]).

-define(WORLD_5, [{player, [{item, helmet},
                            {body_part, head1},
                            {body_part, finger1},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {head1, [{name, <<"head">>},
                           {owner, player},
                           {body_part, head},
                           {icon, body_part},
                           ?BODY_PART_HANDLERS]},
                  {finger1, [{name, <<"finger">>},
                             {owner, player},
                             {body_part, finger},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},
                  {helmet, [{owner, player},
                            {name, <<"helmet">>},
                            {body_parts, [head, hand]},
                            {icon, armor},
                            ?ITEM_HANDLERS]}]).

-define(WORLD_6, [{player, [{body_part, finger1},
                            {body_part, finger2},
                            {item, ring1},
                            {item, ring2},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},
                  {finger1, [{name, <<"finger1">>},
                             {owner, player},
                             {max_items, 1},
                             {body_part, finger},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},
                  {finger2, [{name, <<"finger2">>},
                             {owner, player},
                             {max_items, 1},
                             {body_part, finger},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},
                  {ring1, [{owner, player},
                           {name, <<"ring1">>},
                           {body_parts, [finger]},
                           {icon, clothing},
                           ?ITEM_HANDLERS]},
                  {ring2, [{owner, player},
                           {name, <<"ring2">>},
                           {body_parts, [finger]},
                           {icon, clothing},
                           ?ITEM_HANDLERS]}]).

-define(WORLD_7, [{room, [{character, giant},
                          {name, <<"room">>},
                          {desc, <<"an empty space">>},
                          {item, bread},
                          {icon, room},
                          ?ROOM_HANDLERS]},

                  {player, [{name, <<"Bob">>},
                            {attribute, height0},
                            {attribute, weight0},
                            {attribute, gender0},
                            {attribute, race0},
                            {owner, room},
                            %% TODO is the room property used anywhere?
                            {room, room},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},

                  {height0, [{owner, player},
                             {type, height},
                             {value, <<"2.2">>},
                             {desc, [value, <<"m tall">>]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {weight0, [{owner, player},
                             {type, weight},
                             {value, <<"128">>},
                             {desc, [<<"weighs ">>, value, <<"kg">>]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {gender0, [{owner, player},
                             {type, gender},
                             {value, <<"female">>},
                             {desc, [value]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {race0, [{owner, player},
                           {type, race},
                           {value, <<"human">>},
                           {desc, [value]},
                             {icon, stat},
                           ?ATTRIBUTE_HANDLERS]},

                  {giant, [{owner, room},
                           {name, <<"Pete">>},
                           {item, pants},
                           {item, sword},
                           {item, scroll},
                           {body_part, legs0},
                           {body_part, hands0},
                           {attribute, height1},
                           {attribute, weight1},
                           {attribute, gender1},
                           {attribute, race1},
                           {icon, person},
                           ?CHARACTER_HANDLERS]},

                  {height1, [{owner, giant},
                             {type, height},
                             {value, <<"4.0">>},
                             {desc, [value, <<"m tall">>]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {weight1, [{owner, giant},
                             {type, weight},
                             {value, <<"400.0">>},
                             {desc, [<<"weighs ">>, value, <<"kg">>]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {gender1, [{owner, giant},
                             {type, gender},
                             {value, <<"male">>},
                             {desc, [value]},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]},

                  {race1, [{owner, giant},
                           {type, race},
                           {value, <<"giant">>},
                           {desc, [value]},
                           {icon, stat},
                           ?ATTRIBUTE_HANDLERS]},

                  {legs0, %% if we name this 'legs' then 'legs' will be known as
                          %% as an object ID. If 'legs' is an object identifier
                          %% then a {body_part, legs} property on a body_part,
                          %% i.e. the type of the body part, will be changed
                          %% into {body_part, <PID OF LEGS OBJECT>}
                          [{name, <<"legs">>},
                           {owner, giant},
                           {max_items, 1},
                           {body_part, legs},
                           {icon, body_part},
                           ?BODY_PART_HANDLERS]},
                  {hands0, [{name, <<"hands">>},
                            {owner, giant},
                            {max_items, 1},
                            {body_part, hands},
                            {icon, body_part},
                            ?BODY_PART_HANDLERS]},

                  {pants, [{owner, giant},
                           {body_parts, [legs]},
                           {name, <<"pants_">>},
                           {desc, <<"pants">>},
                           {icon, clothing},
                           ?ITEM_HANDLERS]},
                  {sword, [{owner, giant},
                           {body_parts, [hands]},
                           {name, <<"sword_">>},
                           {desc, <<"sword">>},
                           {icon, weapon},
                           ?ITEM_HANDLERS]},
                  {scroll, [{owner, giant},
                            {body_parts, []},
                            {name, <<"scroll_">>},
                            {desc, <<"scroll">>},
                            {icon, book},
                            ?ITEM_HANDLERS]},
                  {shoes, [{owner, giant},
                           {body_parts, [feet]},
                           {name, <<"shoes_">>},
                           {desc, <<"shoes">>},
                           {icon, clothing},
                           ?ITEM_HANDLERS]},
                  {bread, [{owner, room},
                           {name, <<"bread_">>},
                           {desc, <<"a loaf of bread">>},
                           {icon, food},
                           ?ITEM_HANDLERS]}
                 ]).

-define(WORLD_8, [{room1, [{is_room, true},
                           {character, giant},
                           {character, player},
                           {item, shield},
                           {item, force_field},
                           {name, <<"room">>},
                           {desc, <<"an empty space">>},
                           {exit, exit_1_2},
                           {icon, room},
                           ?ROOM_HANDLERS]},

                  {room2, [{exit, exit_1_2},
                           {icon, room},
                           ?ROOM_HANDLERS]},

                  {exit_1_2, [{{room, r1}, room1},
                              {{room, r2}, room2},
                              {icon, exit},
                              ?EXIT_HANDLERS]},

                  {player, [{name, <<"Bob">>},
                            {owner, room1},
                            {room, room1},
                            {hitpoints, p_hp},
                            {life, p_life},
                            {attribute, strength0},
                            {attribute, dexterity0},
                            {stamina, p_stamina},
                            {body_part, p_back},
                            {body_part, hand0},
                            {body_part, hand1},
                            {race, race0},
                            {icon, person},
                            ?CHARACTER_HANDLERS]},

                  {p_hp, [{hitpoints, 10},
                          {owner, player},
                          {icon, stat},
                          ?HITPOINTS_HANDLERS]},

                  {p_life, [{is_alive, true},
                            {owner, player},
                            {icon, stat},
                            ?LIFE_HANDLERS]},

                  {force_field, [{owner, player},
                                 {body_parts, [back]},
                                 {wielding_body_parts, [back]},
                                 {name, <<"force field">>},
                                 {desc, [name]},
                                 {defence_damage_modifier, 100},
                                 {is_defence, true},
                                 {icon, technology},
                                 ?ITEM_HANDLERS]},

                  {shield, [{owner, player},
                            {body_parts, [hand]},
                            {wielding_body_parts, [hand]},
                            {name, <<"shield">>},
                            {desc, [name]},
                            {defence_hit_modifier, 100},
                            {is_defence, true},
                            {icon, armor},
                            ?ITEM_HANDLERS]},

                  {strength0, [{owner, player},
                               {type, strength},
                               {value, 17},
                               {attack_damage_modifier, 100},
                               {desc, [<<"strength ">>, value]},
                               {icon, stat},
                               ?ATTRIBUTE_HANDLERS]},

                  {dexterity0, [{owner, player},
                                {type, dexterity},
                                {value, 15},
                                {attack_hit_modifier, 100},
                                {desc, [<<"dexterity ">>, value]},
                                {icon, stat},
                                ?ATTRIBUTE_HANDLERS]},

                  {p_stamina, [{owner, player},
                               {type, stamina},
                               {per_tick, 1},
                               {tick_time, 10},
                               {max, 10},
                               {icon, resource},
                               ?RESOURCE_HANDLERS]},

                  {hand0,   [{name, <<"left hand">>},
                             {owner, player},
                             {body_part, hand},
                             {max_items, 1},
                             {item, p_fist},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},

                  {hand1,   [{name, <<"right hand">>},
                             {owner, player},
                             {body_part, hand},
                             {max_items, 1},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},

                  {p_fist, [{name, <<"left fist">>},
                            {attack_damage_modifier, 50},
                            {attack_hit_modifier, 1},
                            {owner, p_hand},
                            {character, player},
                            {wielding_body_parts, [hand]},
                            {body_part, {?PID(hand0), hand}},
                            {is_attack, true},
                            {is_auto_attack, true},
                            {resources, [{stamina, 5}]},
                            {icon, body_part},
                            ?ITEM_HANDLERS]},

                  {p_back,   [{name, <<"back">>},
                             {owner, player},
                             {body_part, back},
                             {max_items, 2},
                             {icon, body_part},
                             ?BODY_PART_HANDLERS]},

                  {giant, [{owner, room1},
                           {name, <<"Pete">>},
                           {hitpoints, g_hp},
                           {life, g_life},
                           {body_part, g_hand_r},
                           {attribute, strength1},
                           {attribute, dexterity1},
                           {attribute, race},
                           {stamina, g_stamina},
                           {icon, person},
                           ?CHARACTER_HANDLERS]},

                  {g_hp, [{hitpoints, 310},
                          {owner, giant},
                          {icon, stat},
                          ?HITPOINTS_HANDLERS]},

                  {g_life, [{is_alive, true},
                            {owner, giant},
                            {icon, stat},
                            ?LIFE_HANDLERS]},

                  {g_hand_r, [{name, <<"right hand">>},
                              {owner, giant},
                              {body_part, hand},
                              {item, g_club},
                              {icon, body_part},
                              ?BODY_PART_HANDLERS]},

                  {strength1, [{owner, giant},
                               {type, strength},
                               {value, 17},
                               {attack_damage_modifier, 50},
                               {desc, [<<"strength ">>, value]},
                               {icon, stat},
                               ?ATTRIBUTE_HANDLERS]},

                  {dexterity1, [{owner, player},
                                {type, dexterity},
                                {value, 15},
                                {attack_hit_modifier, 50},
                                {defence_hit_modifier, 50},
                                {desc, [<<"dexterity ">>, value]},
                                {icon, stat},
                                ?ATTRIBUTE_HANDLERS]},

                  {g_stamina, [{owner, giant},
                               {type, stamina},
                               {per_tick, 1},
                               {tick_time, 10},
                               {max, 10},
                               {icon, resource},
                               ?RESOURCE_HANDLERS]},

                  {race0, [{owner, giant},
                           {defence_damage_modifier, 50},
                           {desc, [<<"giant">>]},
                           {icon, stat},
                           ?ATTRIBUTE_HANDLERS]},

                  {g_club, [{name, <<"giant club">>},
                            {attack_damage_modifier, 50},
                            {attack_hit_modifier, 5},
                            {owner, g_hand_r},
                            {character, giant},
                            {wielding_body_parts, [hand]},
                            {body_part, {?PID(g_hand_r), hand}},
                            {is_attack, true},
                            {is_auto_attack, true},
                            {resources, [{stamina, 5}]},
                            {icon, weapon},
                            ?ITEM_HANDLERS]}
                 ]).

-define(WORLD_9, [{room, [{character, dog},
                          {item, collar},
                          {icon, room},
                          ?ROOM_HANDLERS]},

                  {dog, [{owner, room},
                         {icon, person},
                         ?CHARACTER_HANDLERS]},

                  {collar, [{owner, room},
                            {item, transmitter},
                            {icon, clothing},
                            ?ITEM_HANDLERS]},

                  {transmitter, [{owner, collar},
                                 {attribute, stealth},
                                 {icon, technology},
                                 ?ITEM_HANDLERS]},

                  {stealth, [{owner, transmitter},
                             {icon, stat},
                             ?ATTRIBUTE_HANDLERS]} ]).

-define(WORLD_10, [{room, [{character, player},
                           {item, rifle},
                           {exit, exit_1_2},
                           {icon, exit},
                           ?ROOM_HANDLERS]},

                   {player, [{owner, room},
                             {icon, person},
                             ?CHARACTER_HANDLERS]},

                   {rifle, [{owner, room},
                            {name, <<"rifle">>},
                            {item, suppressor},
                            {item, grip},
                            {item, clip},
                            {icon, weapon},
                            ?ITEM_HANDLERS]},

                   {suppressor, [{owner, rifle},
                                 {name, <<"suppressor">>},
                                 {top_item, rifle},
                                 {icon, weapon},
                                 ?ITEM_HANDLERS]},

                   {grip, [{owner, rifle},
                           {name, <<"grip">>},
                           {top_item, rifle},
                           {icon, weapon},
                           ?ITEM_HANDLERS]},

                   {clip, [{owner, rifle},
                           {name, <<"clip">>},
                           {top_item, rifle},
                           {item, bullet},
                           {icon, weapon},
                           ?ITEM_HANDLERS]},

                   {bullet, [{owner, clip},
                             {name, <<"bullet">>},
                             {top_item, rifle},
                             {icon, ammo},
                             ?ITEM_HANDLERS]} ]).

-define(WORLD_11, [{room,
                       [{character, player},
                        {character, giant},
                        {icon, room},
                        ?ROOM_HANDLERS]},

                   {player,
                       [{owner, room},
                        {room, room},
                        {icon, person},
                        {mana, p_mana},
                        {spell, fireball_spell},
                        ?CHARACTER_HANDLERS]},

                   {p_mana,
                       [{owner, player},
                        {type, mana},
                        {per_tick, 1},
                        {tick_time, 10},
                        {max, 10},
                        {icon, resource},
                        ?RESOURCE_HANDLERS]},

                   {p_hp,
                       [{hitpoints, 10},
                        {owner, player},
                        {icon, stat},
                        ?HITPOINTS_HANDLERS]},

                   {p_life,
                       [{is_alive, true},
                        {owner, player},
                        {icon, stat},
                        ?LIFE_HANDLERS]},

                   {fireball_spell,
                       [{desc, <<"fireball spell">>},
                        {owner, player},
                        {character, player},
                        {name, <<"fireball">>},
                        {effect, fireball_effect},
                        {attack_hit, 10},
                        {attack_types, [spell]},
                        {is_attack, true},
                        {is_auto_attack, true},
                        {resources, [{mana, 5}]},
                        {is_memorized, false},
                        {icon, spell},
                        ?SPELL_HANDLERS]},

                   {fireball_effect,
                       [{desc, <<"fireball spell">>},
                        {owner, fireball_spell},
                        {character, player},
                        {attack_damage, 2},
                        {attack_hit, 10},
                        {attack_effect_hit_modifier, 10},
                        {attack_types, [effect, fire]},
                        {is_attack, false},
                        {is_defence, false},
                        {icon, effect},
                        ?EFFECT_HANDLERS]},

                   {giant,
                       [{owner, room},
                        {room, room},
                        {name, <<"Pete">>},
                        {hitpoints, g_hp},
                        {life, g_life},
                        {icon, person},
                        ?CHARACTER_HANDLERS]},

                   {g_hp,
                       [{hitpoints, 2},
                        {owner, giant},
                        {icon, stat},
                        ?HITPOINTS_HANDLERS]},

                   {g_life,
                       [{is_alive, true},
                        {owner, giant},
                        {icon, stat},
                        ?LIFE_HANDLERS]}]).
