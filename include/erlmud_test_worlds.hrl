-define(ROOM_HANDLERS, {handlers, [erlmud_handler_room_inject_self,
                                   erlmud_handler_room_inv,
                                   erlmud_handler_room_look,
                                   erlmud_handler_room_move,
                                   erlmud_handler_set_character]}).

-define(CHARACTER_HANDLERS, {handlers, [erlmud_handler_char_attack,
                                        erlmud_handler_char_look,
                                        erlmud_handler_char_inv,
                                        erlmud_handler_char_move,
                                        erlmud_handler_char_inject_self,
                                        erlmud_handler_char_enter_world,
                                        erlmud_handler_set_character]}).

-define(ITEM_HANDLERS, {handlers, [erlmud_handler_item_attack,
                                   erlmud_handler_item_look,
                                   erlmud_handler_item_inv,
                                   erlmud_handler_item_inject_self,
                                   erlmud_handler_set_character]}).

-define(CONN_HANDLERS, {handlers, [erlmud_handler_conn_enter_world,
                                   erlmud_handler_conn_move,
                                   erlmud_handler_conn_send,
                                   erlmud_handler_set_character]}).

-define(BODY_PART_HANDLERS, {handlers, [erlmud_handler_body_part_look,
                                        erlmud_handler_body_part_inv,
                                        erlmud_handler_body_part_inject_self,
                                        erlmud_handler_set_character]}).

-define(ATTRIBUTE_HANDLERS, {handlers, [erlmud_handler_attribute_look,
                                        erlmud_handler_set_character]}).

-define(EXIT_HANDLERS, {handlers, [erlmud_handler_exit_move,
                                   erlmud_handler_set_character]}).

-define(HITPOINTS_HANDLERS, {handlers, [erlmud_handler_hitpoints_attack,
                                        erlmud_handler_set_character]}).

-define(LIFE_HANDLERS, {handlers, [erlmud_handler_life_attack,
                                   erlmud_handler_set_character]}).

-define(STAT_HANDLERS, {handlers, [erlmud_handler_stat_look,
                                   erlmud_handler_set_character]}).

-define(TEST_CONN_HANDLERS, {handlers, [erlmud_handler_test_connection_attack,
                                        erlmud_handler_set_character]}).

-define(WORLD_1, [{erlmud_room, room_nw, [{exit, exit_ns}, {exit, exit_ew}, {character, player}, ?ROOM_HANDLERS]},
                  {erlmud_room, room_s, [{exit, exit_ns}, ?ROOM_HANDLERS]},
                  {erlmud_room, room_e, [{exit, exit_ew}, ?ROOM_HANDLERS]},
                  {erlmud_character, player, [{owner, room_nw}, ?CHARACTER_HANDLERS]},
                  {erlmud_exit, exit_ns, [{{room, n}, room_nw}, {{room, s}, room_s}, ?EXIT_HANDLERS]},
                  {erlmud_exit, exit_ew, [{{room, w}, room_nw}, {{room, e}, room_e}, {is_locked, true}, ?EXIT_HANDLERS]}]).

-define(WORLD_2, [{erlmud_room, room, [{player, player}, {item, sword}, {item, apple}, ?ROOM_HANDLERS]},
                  {erlmud_character, player, [{owner, room}, {item, helmet}, ?CHARACTER_HANDLERS]},
                  {erlmud_item, sword, [{owner, room}, {name, <<"sword">>}, ?ITEM_HANDLERS]},
                  {erlmud_item, helmet, [{owner, player}, {name, <<"helmet">>}, ?ITEM_HANDLERS]},
                  {erlmud_item, apple, [{owner, room}, {name, <<"apple">>}, ?ITEM_HANDLERS]}]).

-define(WORLD_3, [{erlmud_room, room, [{character, player},
                                       {character, zombie},
                                       ?ROOM_HANDLERS]},

                  {erlmud_character, player, [{owner, room},
                                              {attack_wait, 10},
                                              {item, fist},
                                              {hitpoints, p_hp},
                                              {life, p_life},
                                              ?CHARACTER_HANDLERS]},
                  {erlmud_hitpoints, p_hp, [{hitpoints, 1000},
                                            {owner, player},
                                            ?HITPOINTS_HANDLERS]},
                  {erlmud_life, p_life, [{is_alive, true},
                                         {owner, player},
                                         ?LIFE_HANDLERS]},
                  {erlmud_item, fist, [{attack_damage_modifier, 5},
                                       {owner, player},
                                       {character, player},
                                       ?ITEM_HANDLERS]},

                  {erlmud_character, zombie, [{owner, room},
                                              {attack_wait, 10},
                                              {item, sword},
                                              {name, <<"zombie">>},
                                              {hitpoints, z_hp},
                                              {life, z_life},
                                              ?CHARACTER_HANDLERS]},
                  {erlmud_hitpoints, z_hp, [{hitpoints, 10},
                                            {owner, zombie},
                                            ?HITPOINTS_HANDLERS]},
                  {erlmud_life, z_life, [{is_alive, true},
                                         {owner, zombie},
                                         ?LIFE_HANDLERS]},
                  {erlmud_item, sword, [{attack_damage_modifier, 5},
                                        {owner, zombie},
                                        {character, zombie},
                                        ?ITEM_HANDLERS]}]).

-define(WORLD_4, [{erlmud_room, room, [{player, player}, ?ROOM_HANDLERS]},
                  {erlmud_character, player, [{owner, room},
                                              {item, helmet},
                                              {body_part, head1},
                                              ?CHARACTER_HANDLERS]},
                  {erlmud_body_part, head1, [{name, <<"head">>},
                                             {body_part, head},
                                             {owner, player}, ?BODY_PART_HANDLERS]},
                  {erlmud_item, helmet, [{name, <<"helmet">>},
                                         {owner, player},
                                         {body_parts, [head]}, ?ITEM_HANDLERS]}]).

-define(WORLD_5, [{erlmud_character, player, [{item, helmet},
                                              {body_part, head1},
                                              {body_part, finger1},
                                              ?CHARACTER_HANDLERS]},
                  {erlmud_body_part, head1, [{name, <<"head">>},
                                             {owner, player},
                                             {body_part, head},
                                             ?BODY_PART_HANDLERS]},
                  {erlmud_body_part, finger1, [{name, <<"finger">>},
                                               {owner, player},
                                               {body_part, finger},
                                               ?BODY_PART_HANDLERS]},
                  {erlmud_item, helmet, [{owner, player},
                                         {name, <<"helmet">>},
                                         {body_parts, [head, hand]},
                                         ?ITEM_HANDLERS]}]).

-define(WORLD_6, [{erlmud_character, player, [{body_part, finger1},
                                              {body_part, finger2},
                                              {item, ring1},
                                              {item, ring2},
                                              ?CHARACTER_HANDLERS]},
                  {erlmud_body_part, finger1, [{name, <<"finger1">>},
                                               {owner, player},
                                               {max_items, 1},
                                               {body_part, finger},
                                               ?BODY_PART_HANDLERS]},
                  {erlmud_body_part, finger2, [{name, <<"finger2">>},
                                               {owner, player},
                                               {max_items, 1},
                                               {body_part, finger},
                                               ?BODY_PART_HANDLERS]},
                  {erlmud_item, ring1, [{owner, player},
                                        {name, <<"ring1">>},
                                        {body_parts, [finger]},
                                        ?ITEM_HANDLERS]},
                  {erlmud_item, ring2, [{owner, player},
                                        {name, <<"ring2">>},
                                        {body_parts, [finger]},
                                        ?ITEM_HANDLERS]}]).

-define(WORLD_7, [{erlmud_room, room, [{character, giant},
                                       {name, <<"room">>},
                                       {desc, <<"an empty space">>},
                                       {item, bread},
                                       ?ROOM_HANDLERS]},

                  {erlmud_character, player, [{name, <<"Bob">>},
                                              {attribute, height0},
                                              {attribute, weight0},
                                              {attribute, gender0},
                                              {attribute, race0},
                                              ?CHARACTER_HANDLERS]},

                  {erlmud_attribute, height0, [{owner, player},
                                               {type, height},
                                               {value, <<"2.2">>},
                                               {desc, [value, <<"m tall">>]},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, weight0, [{owner, player},
                                               {type, weight},
                                               {value, <<"128">>},
                                               {desc, <<"weighs ">>, value, <<"kg">>},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, gender0, [{owner, player},
                                               {type, gender},
                                               {value, <<"female">>},
                                               {desc, [value]},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, race0, [{owner, player},
                                             {type, race},
                                             {value, <<"human">>},
                                             {desc, [value]},
                                             ?ATTRIBUTE_HANDLERS]},

                  {erlmud_character, giant, [{owner, room},
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
                                             ?CHARACTER_HANDLERS]},

                  {erlmud_attribute, height1, [{owner, giant},
                                               {type, height},
                                               {value, <<"4.0">>},
                                               {desc, [value, <<"m tall">>]},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, weight1, [{owner, giant},
                                               {type, weight},
                                               {value, <<"400.0">>},
                                               {desc, [<<"weighs ">>, value, <<"kg">>]},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, gender1, [{owner, giant},
                                               {type, gender},
                                               {value, <<"male">>},
                                               {desc, [value]},
                                               ?ATTRIBUTE_HANDLERS]},

                  {erlmud_attribute, race1, [{owner, giant},
                                             {type, race},
                                             {value, <<"giant">>},
                                             {desc, [value]},
                                             ?ATTRIBUTE_HANDLERS]},

                  {erlmud_body_part, legs0, %% if we name this 'legs' then 'legs' will be known as
                                            %% as an object ID. If 'legs' is an object identifier
                                            %% then a {body_part, legs} property on a body_part,
                                            %% i.e. the type of the body part, will be changed
                                            %% into {body_part, <PID OF LEGS OBJECT>}
                                              [{name, <<"legs">>},
                                               {owner, giant},
                                               {max_items, 1},
                                               {body_part, legs},
                                               ?BODY_PART_HANDLERS]},
                  {erlmud_body_part, hands0,   [{name, <<"hands">>},
                                                {owner, giant},
                                                {max_items, 1},
                                                {body_part, hands},
                                                ?BODY_PART_HANDLERS]},

                  {erlmud_item, pants, [{owner, giant},
                                        {body_parts, [legs]},
                                        {name, <<"pants_">>},
                                        {desc, <<"pants">>},
                                        ?ITEM_HANDLERS]},
                  {erlmud_item, sword, [{owner, giant},
                                        {body_parts, [hands]},
                                        {name, <<"sword_">>},
                                        {desc, <<"sword">>},
                                        ?ITEM_HANDLERS]},
                  {erlmud_item, scroll, [{owner, giant},
                                         {body_parts, []},
                                         {name, <<"scroll_">>},
                                         {desc, <<"scroll">>},
                                         ?ITEM_HANDLERS]},
                  {erlmud_item, shoes, [{owner, giant},
                                        {body_parts, [feet]},
                                        {name, <<"shoes_">>},
                                        {desc, <<"shoes">>},
                                        ?ITEM_HANDLERS]},
                  {erlmud_item, bread, [{owner, room},
                                        {name, <<"bread_">>},
                                        {desc, <<"a loaf of bread">>},
                                        ?ITEM_HANDLERS]}
                 ]).

-define(WORLD_8, [{room, [{is_room, true},
                          {character, giant},
                          {character, player},
                          {name, <<"room">>},
                          {desc, <<"an empty space">>},
                          ?ROOM_HANDLERS]},

                  {player, [{name, <<"Bob">>},
                            {owner, room},
                            {attribute, strength},
                            {attribute, dexterity},
                            {item, force_field},
                            {item, shield},
                            {body_part, back0},
                            {body_part, hand0},
                            ?CHARACTER_HANDLERS]},

                  {p_hp, [{hitpoints, 10},
                          {owner, player},
                          ?HITPOINTS_HANDLERS]},

                  {p_life, [{is_alive, true},
                            {owner, player},
                            ?LIFE_HANDLERS]},

                  {force_field, [{owner, player},
                                 {body_parts, [back]},
                                 {name, <<"force field">>},
                                 {desc, [name]},
                                 {defence_damage_modifier, -100},
                                 ?ITEM_HANDLERS]},

                  {shield, [{owner, player},
                            {body_parts, [hand]},
                            {name, <<"shield">>},
                            {desc, [name]},
                            {defence_hit_modifier, -100},
                            ?ITEM_HANDLERS]},

                  {strenth0, [{owner, player},
                              {type, strength},
                              {value, 17},
                              {attack_damage_modifier, 100},
                              {desc, [<<"strength ">>, value]},
                              ?ATTRIBUTE_HANDLERS]},

                  {dex0, [{owner, player},
                          {type, dexterity},
                          {value, 15},
                          {attack_hit_modifier, 100},
                          {desc, [<<"dexterity ">>, value]},
                          ?ATTRIBUTE_HANDLERS]},

                  {hand0,   [{name, <<"left hand">>},
                             {owner, player},
                             {body_part, hand},
                             ?BODY_PART_HANDLERS]},

                  {back0,   [{name, <<"back">>},
                             {owner, player},
                             {body_part, back},
                             ?BODY_PART_HANDLERS]},

                  {giant, [{owner, room},
                           {name, <<"Pete">>},
                           {body_part, hand1},
                           {handlers, [erlmud_handler_counterattack,
                                       erlmud_handler_char_attack,
                                       erlmud_handler_char_look,
                                       erlmud_handler_char_inv,
                                       erlmud_handler_char_move,
                                       erlmud_handler_char_inject_self,
                                       erlmud_handler_char_enter_world]}]},

                  {g_hp, [{hitpoints, 10},
                          {owner, giant},
                          ?HITPOINTS_HANDLERS]},

                  {g_life, [{is_alive, true},
                            {owner, giant},
                            ?LIFE_HANDLERS]},

                  {hand1,   [{name, <<"right hand">>},
                             {owner, player},
                             {body_part, hand},
                             ?BODY_PART_HANDLERS]},

                  {strenth0, [{owner, player},
                              {type, strength},
                              {value, 17},
                              {attack_damage_modifier, 50},
                              {desc, [<<"strength ">>, value]},
                              ?ATTRIBUTE_HANDLERS]},

                  {dex0, [{owner, player},
                          {type, dexterity},
                          {value, 15},
                          {attack_hit_modifier, 50},
                          {defence_hit_modifier, 50},
                          {desc, [<<"dexterity ">>, value]},
                          ?ATTRIBUTE_HANDLERS]},

                  {race, [{owner, player},
                          {type, dexterity},
                          {value, 15},
                          {defence_damage_modifier, 50},
                          {desc, [<<"giant">>, value]},
                          ?ATTRIBUTE_HANDLERS]}
                 ]).

-define(WORLD_9, [{erlmud_room, room, [{character, dog},
                                       {item, collar},
                                       ?ROOM_HANDLERS]},

                  {erlmud_character, dog, [{owner, room},
                                           ?CHARACTER_HANDLERS]},

                  {erlmud_item, collar, [{owner, room},
                                         {item, transmitter},
                                         ?ITEM_HANDLERS]},

                  {erlmud_item, transmitter, [{owner, collar},
                                              {attribute, stealth},
                                              ?ITEM_HANDLERS]},

                  {erlmud_attribute, stealth, [{owner, transmitter},
                                               ?ATTRIBUTE_HANDLERS]} ]).
