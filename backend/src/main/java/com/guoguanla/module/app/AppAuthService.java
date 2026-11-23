package com.guoguanla.module.app;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.guoguanla.common.exception.BizException;
import com.guoguanla.common.result.ErrorCode;
import com.guoguanla.common.security.StpAppUtil;
import com.guoguanla.module.app.dto.AppLoginReq;
import com.guoguanla.module.app.vo.AppUserProfileVO;
import com.guoguanla.module.bank.entity.EduGate;
import com.guoguanla.module.bank.mapper.EduGateMapper;
import com.guoguanla.module.progress.entity.UserGateProgress;
import com.guoguanla.module.progress.mapper.UserGateProgressMapper;
import com.guoguanla.module.system.RealmHelperService;
import com.guoguanla.module.system.entity.EduRealm;
import com.guoguanla.module.user.entity.AppUser;
import com.guoguanla.module.user.mapper.AppUserMapper;
import lombok.RequiredArgsConstructor;
import org.mindrot.jbcrypt.BCrypt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AppAuthService {

    private final AppUserMapper userMapper;
    private final EduGateMapper gateMapper;
    private final UserGateProgressMapper gateProgressMapper;
    private final AppBankService bankService;
    private final RealmHelperService realmHelper;

    @Transactional(rollbackFor = Exception.class)
    public AppUserProfileVO.AuthVO login(AppLoginReq req) {
        String acct = req.getAccount().trim();
        AppUser user = userMapper.selectOne(
                new LambdaQueryWrapper<AppUser>()
                        .and(w -> w.eq(AppUser::getUsername, acct).or().eq(AppUser::getPhone, acct))
                        .last("LIMIT 1")
        );
        if (user == null || user.getPasswordHash() == null
                || !BCrypt.checkpw(req.getPassword(), user.getPasswordHash())) {
            throw new BizException(ErrorCode.AUTH_FAILED);
        }
        if (user.getStatus() == null || user.getStatus() == 0) {
            throw new BizException(ErrorCode.ACCOUNT_DISABLED);
        }

        mergeGuestPasses(user, req.getGuestPassedGateIds());
        user.setLastActiveAt(LocalDateTime.now());
        userMapper.updateById(user);

        String token = StpAppUtil.login(user.getId());
        return AppUserProfileVO.AuthVO.builder()
                .token(token)
                .profile(bankService.buildProfileVO(user))
                .build();
    }

    @Transactional(rollbackFor = Exception.class)
    public AppUserProfileVO.AuthVO register(AppLoginReq.RegisterReq req) {
        String username = req.getUsername().trim();
        long exists = userMapper.selectCount(
                new LambdaQueryWrapper<AppUser>().eq(AppUser::getUsername, username)
        );
        if (exists > 0) {
            throw new BizException(ErrorCode.USER_EXISTS, "用户名已被注册");
        }
        String gradeCode = req.getGradeCode() == null ? "" : req.getGradeCode().trim();
        EduRealm targetRealm = realmHelper.findByGradeCode(gradeCode);
        if (targetRealm == null) {
            throw new BizException(ErrorCode.BAD_REQUEST, "请选择有效的年级");
        }
        AppUser user = new AppUser();
        user.setUsername(username);
        user.setPasswordHash(BCrypt.hashpw(req.getPassword(), BCrypt.gensalt()));
        user.setNickname(req.getNickname().trim());
        user.setRealmCode(targetRealm.getRealmCode());
        user.setGradeCode(targetRealm.getGradeCode());
        user.setPassedGateCount(0);
        user.setCurrentLevelId(1L);
        user.setStatus(1);
        user.setLastActiveAt(LocalDateTime.now());
        userMapper.insert(user);

        mergeGuestPasses(user, req.getGuestPassedGateIds());
        userMapper.updateById(user);

        String token = StpAppUtil.login(user.getId());
        return AppUserProfileVO.AuthVO.builder()
                .token(token)
                .profile(bankService.buildProfileVO(user))
                .build();
    }

    public void logout() {
        StpAppUtil.logout();
    }

    private void mergeGuestPasses(AppUser user, List<Long> guestPassedGateIds) {
        if (guestPassedGateIds == null || guestPassedGateIds.isEmpty()) {
            return;
        }
        List<EduGate> gates = gateMapper.selectBatchIds(guestPassedGateIds);
        LocalDateTime now = LocalDateTime.now();
        for (EduGate gate : gates) {
            UserGateProgress exist = gateProgressMapper.selectOne(
                    new LambdaQueryWrapper<UserGateProgress>()
                            .eq(UserGateProgress::getUserId, user.getId())
                            .eq(UserGateProgress::getGateId, gate.getId())
                            .last("LIMIT 1")
            );
            if (exist == null) {
                UserGateProgress prog = new UserGateProgress();
                prog.setUserId(user.getId());
                prog.setChapterId(gate.getChapterId());
                prog.setGateId(gate.getId());
                prog.setGateIndex(gate.getGateIndex());
                prog.setIsPassed(1);
                prog.setBestCorrect(gate.getPassCount());
                prog.setAttemptCount(1);
                prog.setFirstPassedAt(now);
                prog.setLastPlayedAt(now);
                gateProgressMapper.insert(prog);
            } else if (exist.getIsPassed() == 0) {
                exist.setIsPassed(1);
                exist.setFirstPassedAt(now);
                exist.setLastPlayedAt(now);
                gateProgressMapper.updateById(exist);
            }
        }
        long distinctPassed = gateProgressMapper.selectCount(
                new LambdaQueryWrapper<UserGateProgress>()
                        .eq(UserGateProgress::getUserId, user.getId())
                        .eq(UserGateProgress::getIsPassed, 1)
        );
        user.setPassedGateCount(Math.max(user.getPassedGateCount() == null ? 0 : user.getPassedGateCount(), (int) distinctPassed));
        user.setCurrentLevelId(bankService.resolveLevelId(user.getPassedGateCount()));
    }
}
