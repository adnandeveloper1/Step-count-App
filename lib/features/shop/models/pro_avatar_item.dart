/// The Pro Avatar Frame store item, read from a user's Firestore profile.
///
/// Owning it is `unlockedItems` containing [proAvatarItemId]. Showing it also
/// needs [proAvatarEquippedField] to be true; a missing field counts as
/// equipped so people who bought the frame before equip existed keep it.
const proAvatarItemId = 'avatar_pro';
const proAvatarPrice = 500;
const proAvatarEquippedField = 'proAvatarEquipped';

bool ownsProAvatar(Map<String, dynamic>? profile) =>
    (profile?['unlockedItems'] as List?)?.contains(proAvatarItemId) ?? false;

bool showsProAvatar(Map<String, dynamic>? profile) =>
    ownsProAvatar(profile) &&
    (profile?[proAvatarEquippedField] as bool? ?? true);
